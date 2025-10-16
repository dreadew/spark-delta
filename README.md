# Apache Spark 4.0.1 with Delta Lake and S3 Support

Lightweight Docker image for Apache Spark 4.0.1 (JDK 21) with built-in Delta Lake and AWS S3 integration.

## Features

- Apache Spark 4.0.1 (Hadoop 3.4)
- Delta Lake 3.2.1
- AWS SDK for S3
- Python 3 + PySpark + pandas + pyarrow

## Quick Start

1. Build the image:

   ```bash
   docker build -t spark_local .
   ```

2. Use it in your `docker-compose.yml` or run interactively:

   ```bash
   docker run -it spark_local
   ```

## Exposed Ports

- 7077 – Spark Master
- 8080 – Spark Master Web UI
- 8081 – Spark Worker Web UI
- 4040 – Spark Application UI
