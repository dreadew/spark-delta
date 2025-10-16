#!/bin/bash
set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

export SPARK_HOME=${SPARK_HOME:-/opt/spark}
export SPARK_MODE=${SPARK_MODE:-master}
export SPARK_MASTER_HOST=${SPARK_MASTER_HOST:-0.0.0.0}
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}
export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT:-8080}
export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-8081}
export SPARK_WORKER_CORES=${SPARK_WORKER_CORES:-2}
export SPARK_WORKER_MEMORY=${SPARK_WORKER_MEMORY:-2G}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export S3_ENDPOINT=${S3_ENDPOINT:-http://minio:9000}

log "Starting Spark in ${SPARK_MODE} mode"

case "${SPARK_MODE}" in
    master)
        log "Starting Spark Master on ${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT}"
        log "Web UI will be available on port ${SPARK_MASTER_WEBUI_PORT}"
        
        exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.master.Master \
            --host ${SPARK_MASTER_HOST} \
            --port ${SPARK_MASTER_PORT} \
            --webui-port ${SPARK_MASTER_WEBUI_PORT} \
            ${SPARK_MASTER_OPTS}
        ;;
        
    worker)
        log "Starting Spark Worker"
        log "Connecting to Master: spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT}"
        log "Worker cores: ${SPARK_WORKER_CORES}, memory: ${SPARK_WORKER_MEMORY}"
        log "Web UI will be available on port ${SPARK_WORKER_WEBUI_PORT}"
        
        until nc -z ${SPARK_MASTER_HOST} ${SPARK_MASTER_PORT}; do
            log "Waiting for Spark Master to be available..."
            sleep 2
        done
        
        log "Spark Master is available, starting worker..."
        
        exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.worker.Worker \
            spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT} \
            --cores ${SPARK_WORKER_CORES} \
            --memory ${SPARK_WORKER_MEMORY} \
            --webui-port ${SPARK_WORKER_WEBUI_PORT} \
            ${SPARK_WORKER_OPTS}
        ;;
        
    shell)
        log "Starting PySpark Shell"
        exec ${SPARK_HOME}/bin/pyspark \
            --master spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT} \
            --conf spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT} \
            --conf spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID} \
            --conf spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY} \
            --conf spark.hadoop.fs.s3a.path.style.access=true \
            --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
            --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
            --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog
        ;;
        
    submit)
        log "Starting Spark Submit"
        shift
        exec ${SPARK_HOME}/bin/spark-submit \
            --master spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT} \
            --conf spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT} \
            --conf spark.hadoop.fs.s3a.access.key=${AWS_ACCESS_KEY_ID} \
            --conf spark.hadoop.fs.s3a.secret.key=${AWS_SECRET_ACCESS_KEY} \
            --conf spark.hadoop.fs.s3a.path.style.access=true \
            --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
            --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
            --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \
            "$@"
        ;;
        
    *)
        log "ERROR: Unknown mode: ${SPARK_MODE}"
        log "Available modes: master, worker, shell, submit"
        exit 1
        ;;
esac
