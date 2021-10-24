# [Building a Complex, Realtime Data Management Application with PostgreSQL](https://www.slideshare.net/jkatz05/build-a-complex-realtime-data-management-app-with-postgres-14) - Demo Code

Compliments the [Building a Complex, Realtime Data Management Application with PostgreSQL](https://www.slideshare.net/jkatz05/build-a-complex-realtime-data-management-app-with-postgres-14) presentation:

[https://www.slideshare.net/jkatz05/build-a-complex-realtime-data-management-app-with-postgres-14](https://www.slideshare.net/jkatz05/build-a-complex-realtime-data-management-app-with-postgres-14)

## How to Use This Repository

This provides all of the examples that are used in the [Building a Complex, Realtime Data Management Application with PostgreSQL](https://www.slideshare.net/jkatz05/build-a-complex-realtime-data-management-app-with-postgres-14) presentation. You can follow along as a reference, or run the examples on your own.

This README provides a guide for setting up all the resources you need in a Kubernetes environment and guidance for running the demo. You do not necessarily need to use Kubernetes to set up the various components of the demo, but this is utilizing tools that make it easier to set up distributed environments.

Note that the demo is broken up into several different parts. This README will provide guidance on where each demo is run in the context of the presentation.

## General Notes

- All of the examples are run in the `postgres-operator` namespace. You may need to create this:

```
kubectl create ns
```

- The example uses PostgreSQL 14. There is a dependency on `wal2json`. This is included in the `crunchy-postgres` container.
- The database used in the application is called `realtime`.
- When running the example application, you will need to have a logical replication slot defined in the database you are running the examples (e.g. `realtime`). For example:

```
SELECT * FROM pg_create_logical_replication_slot('schedule', 'wal2json');
```

## Installation

### `postgres-realtime-demo`

You may need to make some changes to the `manifests` provided in this repository. As such, you should [fork this repository](https://github.com/CrunchyData/postgres-operator-examples/fork) and clone it to your host machine. For example:

```
YOUR_GITHUB_UN="<your GitHub username>"
git clone --depth 1 "git@github.com:${YOUR_GITHUB_UN}/postgres-operator-examples.git"
```

### [PGO](https://github.com/CrunchyData/postgres-operator), the open source [Postgres Operator](https://github.com/CrunchyData/postgres-operator) from [Crunchy Data](https://www.crunchydata.com/)

[PGO](https://github.com/CrunchyData/postgres-operator), the [Postgres Operator](https://github.com/CrunchyData/postgres-operator) from [Crunchy Data](https://www.crunchydata.com), gives you a **declarative Postgres** solution that automatically manages your [PostgreSQL](https://www.postgresql.org) clusters.

PGO is easy to set up. You can follow the [quickstart](https://access.crunchydata.com/documentation/postgres-operator/v5/quickstart/), or follow the instructions below:

1. [Fork the Postgres Operator examples repository](https://github.com/CrunchyData/postgres-operator-examples/fork) and clone it to your host machine. For example:

```
YOUR_GITHUB_UN="<your GitHub username>"
git clone --depth 1 "git@github.com:${YOUR_GITHUB_UN}/postgres-operator-examples.git"
cd postgres-operator-examples
```

2. Run `kubectl apply -k kustomize/install`

3. Go back to this repository:

```
cd ../postgres-realtime-demo
```

4. Deploy the Postgres cluster example from the `manifests` directory:

```
kubectl apply -k manifests/postgres
```

Your PostgreSQL cluster will now be deployed.

5. There are several ways to [connect to your Postgres](https://access.crunchydata.com/documentation/postgres-operator/v5/tutorial/connect-cluster/) cluster. The examples are already configured to connect automatically to your Postgres cluster.

If you want to manually connect to the cluster, you can do so with the following command:

```
kubectl exec -it -c database -n postgres-operator \
  $(kubectl get pods -o name \
    -n postgres-operator \
    --selector=postgres-operator.crunchydata.com/role=master,postgres-operator.crunchydata.com/cluster=realtime) \
  -- psql realtime
```

Or follow one of the [`psql` methods in the quickstart](https://access.crunchydata.com/documentation/postgres-operator/v5/quickstart/#connect-via-psql-in-the-terminal).

### Kafka

Kafka can be installed using the [Strimzi](https://strimzi.io/) Kubernetes Operator.

1. Install the Strimzi Operator into the `postgres-operator` namespace:

```
kubectl create -f 'https://strimzi.io/install/latest?namespace=postgres-operator' -n postgres-operator
```

2. Once the Strimzi Operator is installed, create a Kafka broker and topics:

```
kubectl apply -k manifests/kafka
```

### Application

1. Before installing the application, you will need to ensure that you have created the schema needed to run the application in the database. You can do this by running the SQL in [demo5.sql](./examples/demo/demo5.sql) in the `realtime` database.

2. You will also need to create a logical replication slot in the `realtime` database:

```
SELECT * FROM pg_create_logical_replication_slot('schedule', 'wal2json');
```

3. You may need to build the container and push it to your registry. You can do this from the `Makefile`. There are several variables you can tune to build the container for your registry:

| Variable          | Usage                           | Default                  |
|-------------------|---------------------------------|--------------------------|
| `BUILDER`         | The container image builder     | `podman`                 |
| `IMAGE_NAME`      | The name of the image           | `postgres-realtime-demo` |
| `IMAGE_REGISTRY`  | The registry to store the image | `crunchydata`            |
| `IMAGE_TAG`       | The tag of the image            | `latest`                 |

For example, to build an image for your own registry (giving it the name `your-registry`):

```
IMAGE_REGISTRY=your-registry make
```

To build the image with docker:

```
BUILDER=docker make
```

To build and push the image to your registry:

```
IMAGE_REGISTRY=your-registry make build push
```

4. Once the image is pushed to your registry, you can deploy the application.

First, set the name of the image in the `manifests/app/kustomization.yaml` file. You can do this by uncommenting this section:

```yaml
images:
  - name: crunchydata/postgres-realtime-demo
    newName: your-registry/postgres-realtime-demo
```

and setting `newName` to the name of your image. Assuming you kept the tag name of `latest`, you do not need to make any additional changes.

## Running the Example

Once you have deployed PostgreSQL, Kafka, and the application, you can run the example found in [demo6.sql](./examples/demo/demo6.sql).

## Advanced

### Application Configuration

There are several environmental variables available for the application that you can set on the Pod.

| Variable                           | Usage                           |
|------------------------------------|---------------------------------|
| `POSTGRES_URI`                     | A PostgreSQL URI. You can use this, or break out each Postgres connection parameter into its own setting. |
| `POSTGRES_HOST`                    | The host representing a PostgreSQL instance.           |
| `POSTGRES_PORT`                    | The port representing a PostgreSQL instance.           |
| `POSTGRES_USER`                    | The PostgreSQL user to login as.           |
| `POSTGRES_PASSWORD`                | The password of the PostgreSQL user.           |
| `POSTGRES_DBNAME`                  | The PostgreSQL database to login to.           |
| `STRIMZI_KAFKA_BOOTSTRAP_SERVERS`  | Reference to the `advertised-hostnames.config` that Strimzi creates for Kafka bootstrap servers. Use this, or the breakout Kafka settings. |
| `KAFKA_BOOTSTRAP_SERVERS`          | A comma-separated list of Kafka bootstrap servers.            |
