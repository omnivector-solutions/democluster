"""Main typer app."""
import typer

from image_factory import builder
from image_factory.config import Settings

app = typer.Typer(name="Image Factory", add_completion=False)
app.add_typer(builder.app, name="build", help="Entrypoing for building the custom images.")


@app.callback()
def settings(
    ctx: typer.Context,
    project_name: str = typer.Option(
        "image-factory",
        envvar="IF_PROJECT_NAME",
        help="The LXD project in which resources are going to be created",
    ),
):
    """Instantiate the settings class as object in the context."""
    ctx.obj = Settings(project_name=project_name)


if __name__ == "__main__":
    app()
