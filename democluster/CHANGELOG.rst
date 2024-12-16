=========
Changelog
=========

Tracking of all notable changes to the Demo Cluster image.

Unreleased
----------

0.4.0 - 2024-11-25
------------------

- Install the Jobbergate Agent and the Vantage Agent from the Snap Store in classic mode (`PENG-2372`_).

.. _PENG-2372: https://app.clickup.com/t/18022949/PENG-2372

0.3.0 - 2024-10-13
------------------

- Implement support for the InfluxDB integration with job metrics (`PENG-2467`_).

.. _PENG-2467: https://app.clickup.com/t/18022949/PENG-2467

0.2.0 - 2023-09-20
------------------

- Patch the demo cluster image to use the Jobbergate Agent instead of the Cluster Agent.
- Patch the *deploy-democluster.sh* script to also set up the Jobbergate Agent instead of the Cluster Agent.

0.1.0 - 2023-08-29
------------------

- First implementation of the demo cluster image.