# DevPlatform

This is an experiment to set up a development platform on a cheap single-node server. It should contain everything to deploy web applications.

- postgres database
- kubernetes (k0s)
- container registry
- local storage for file uploads
- ingress

## To update

Currently, the IP address of the server is hardcoded in the following files and has to be changed before deployment:

- workloads/postgres-service/service.yaml

The name of the server ("devplatform01") has to be changed in the following files:

- workloads/demo/demo-workload.yaml