FROM eclipse-temurin:21-jre-jammy

# Metadata
LABEL maintainer="Developer"
LABEL description="Apache Spark 4.0.1 with Delta Lake and S3 support (JDK 21)"
LABEL version="4.0.1"
LABEL java.version="21"

# Environment variables for Spark
ENV SPARK_VERSION=4.0.1 \
    HADOOP_VERSION=3.4.0 \
    DELTA_VERSION=3.3.2 \
    AWS_SDK_VERSION=2.35.8 \
    JAXB_VERSION=2.3.1 \
    JAXB_CORE_VERSION=4.0.6 \
    SPARK_HOME=/opt/spark

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-openbsd \
    curl \
    wget \
    procps \
    software-properties-common \
    tini && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-distutils \
    python3.11-venv \
    python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3.11 -m pip install --no-cache-dir uv

ENV PYSPARK_PYTHON=/usr/bin/python3.11 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3.11 \
    PYTHONHASHSEED=1

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
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_VERSION}/bundle-${AWS_SDK_VERSION}.jar && \
    # JAXB dependencies for Java 9+
    wget -q https://repo1.maven.org/maven2/javax/xml/bind/jaxb-api/${JAXB_VERSION}/jaxb-api-${JAXB_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-impl/${JAXB_CORE_VERSION}/jaxb-impl-${JAXB_CORE_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-core/${JAXB_CORE_VERSION}/jaxb-core-${JAXB_CORE_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-osgi/${JAXB_CORE_VERSION}/jaxb-osgi-${JAXB_CORE_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-xjc/${JAXB_CORE_VERSION}/jaxb-xjc-${JAXB_CORE_VERSION}.jar && \
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
