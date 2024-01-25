"""Main module for configuration porpuses related to the CLI app."""
from dataclasses import dataclass


@dataclass
class Settings:
    """Common settings for the entire app."""

    project_name: str
