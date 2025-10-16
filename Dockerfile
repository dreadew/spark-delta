FROM eclipse-temurin:21-jre-jammy

# Metadata
LABEL maintainer="Developer"
LABEL description="Apache Spark 4.0.1 with Delta Lake and S3 support (JDK 21)"
LABEL version="4.0.1"
LABEL java.version="21"

# Environment variables for Spark
ENV SPARK_VERSION=4.0.1 \
    HADOOP_VERSION=3.4 \
    DELTA_VERSION=3.2.1 \
    AWS_SDK_VERSION=1.12.262 \
    SPARK_HOME=/opt/spark \
    PYTHONHASHSEED=1 \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    procps \
    python3 \
    python3-pip \
    tini && \
    pip install --no-cache-dir uv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r spark --gid=1000 && \
    useradd -r -g spark --uid=1000 --home-dir=/opt/spark --shell=/bin/bash spark

RUN mkdir -p ${SPARK_HOME} && \
    curl -fsSL https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz | \
    tar -xzC ${SPARK_HOME} --strip-components=1 && \
    chown -R spark:spark ${SPARK_HOME}

RUN uv pip install --system --no-cache \
    pyspark==${SPARK_VERSION} \
    delta-spark \
    boto3 \
    pandas \
    pyarrow \
    numpy

RUN cd ${SPARK_HOME}/jars && \
    # Delta Lake
    wget -q https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/${DELTA_VERSION}/delta-spark_2.13-${DELTA_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    # AWS SDK for S3
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.0/hadoop-aws-3.4.0.jar && \
    chown spark:spark *.jar

RUN mkdir -p ${SPARK_HOME}/logs ${SPARK_HOME}/work ${SPARK_HOME}/conf ${SPARK_HOME}/tmp && \
    chown -R spark:spark ${SPARK_HOME}/logs ${SPARK_HOME}/work ${SPARK_HOME}/conf ${SPARK_HOME}/tmp

COPY --chown=spark:spark conf/spark-defaults.conf ${SPARK_HOME}/conf/
COPY --chown=spark:spark scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

USER spark

WORKDIR ${SPARK_HOME}

# Expose ports
# 8080 - Spark Master Web UI
# 7077 - Spark Master
# 8081 - Spark Worker Web UI
# 4040 - Spark Application Web UI
EXPOSE 8080 7077 8081 4040

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "org.apache.spark" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["master"]
