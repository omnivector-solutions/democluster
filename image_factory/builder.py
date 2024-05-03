"""Public module to define commands related to the build process of the custom machines."""
import os
import uuid
from enum import Enum
from pathlib import Path
from subprocess import TimeoutExpired, check_output
from time import sleep

import typer
import yaml
from craft_providers import lxd
from rich import print
from typing_extensions import Annotated

app = typer.Typer()


class _DemoClusterStages(str, Enum):
    """
    Build stages for the demo cluster.

    Check out the `democluster/Makefile` file for more details.
    """

    stage0 = "stage0"
    final = "final"
    all = "all"


@app.callback()
def project_callback(ctx: typer.Context):
    """Create the LXD project in case it doesn't exist yet."""
    lxc = lxd.LXC()
    if ctx.obj.project_name not in lxc.project_list():
        print(f"Project [bold]{ctx.obj.project_name}[/bold] doesn't exist. [green]Creating it![/green]")
        lxc.project_create(project=ctx.obj.project_name)


def _set_profile(profile_name: str, project_name: str):
    """Customize the default profile to include the profile at `lxd-profile.yaml`."""
    lxc = lxd.LXC()
    profile_as_dict = yaml.safe_load(Path("lxd-profile.yaml").read_text())
    lxc.profile_edit(profile=profile_name, config=profile_as_dict, project=project_name)


@app.command("democluster")
def democluster(
    ctx: typer.Context,
    stage: Annotated[_DemoClusterStages, typer.Option(case_sensitive=False)] = _DemoClusterStages.all,
):
    """Build the Vantage demo cluster."""
    lxc = lxd.LXC()

    short_uuid = f"{uuid.uuid4()}"[:8]
    instance_name = f"democluster-builder-{short_uuid}"

    # Set the default profile to include our custom profile
    print(f"Customizing profile [bold]default[/bold] for project [bold]{ctx.obj.project_name}[/bold]")
    _set_profile(profile_name="default", project_name=ctx.obj.project_name)

    print(f"Launching build instance: {instance_name}")
    lxc.launch(
        instance_name=instance_name,
        image="ubuntu/jammy/amd64",
        image_remote="local",
        project=ctx.obj.project_name,
        config_keys={"limits.cpu": "8", "limits.memory": "6GiB"},
    )

    # Mount needed directories into the instance
    lxd_instance = lxd.LXDInstance(name=instance_name, project="image-factory")
    lxd_instance.mount(host_source=Path(os.getcwd()), target=Path("/srv/image-factory"))

    # If you already have a packer cache in your home, mount it to speed things up
    packer_cache = Path.home() / ".cache" / "packer"
    if packer_cache.exists():
        lxd_instance.mount(host_source=packer_cache, target=Path("/root/.cache/packer"))

    # Wait for cloud-init to finish, then execute the build command in the container
    command = [
        "lxc",
        "exec",
        instance_name,
        f"--project={ctx.obj.project_name}",
        "--",
        "bash",
        "-c",
        "python3 -W ignore /usr/bin/cloud-init status",
    ]

    print("Waiting for cloud-init to finish ...")
    while True:
        try:
            out = check_output(command, timeout=360)
            if "done" not in out.decode():
                sleep(5)
            else:
                break
        except TimeoutExpired:
            typer.echo("[bold red]Time out while waiting for cloud-init to finish.[/bold red]")
            typer.Exit(124)

    print("Kicking off packer build in LXD container.")
    command = ["make", stage.value]
    if jg_version := os.getenv("JG_VERSION"):
        command = ["JG_VERSION={jg_version}"] + command
    lxc.exec(
        command=command,
        cwd="/srv/image-factory/democluster",
        instance_name=instance_name,
        project=ctx.obj.project_name,
    )

    print("[bold green]Build complete, destroying LXD container.[/bold green]")
    lxc.delete(instance_name=instance_name, project=ctx.obj.project_name, force=True)
