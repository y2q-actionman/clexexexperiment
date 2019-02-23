#!/bin/bash

cd `dirname $0`

LAMBDA_FUNC_NAME=${LAMBDA_FUNC_NAME:-"load_other_fasls"}
LAMBDA_ROLE=${LAMBDA_ROLE:-""}
LAMBDA_LAYER=${LAMBDA_LAYER:-""}
ZIP_FILE=$LAMBDA_FUNC_NAME.zip

# build fasls in VM
ASD_FILE=needed-libs.asd
ASD_SYSTEM_NAME=":needed-libs"

docker run --rm \
       --env ASD_FILE=${ASD_FILE} \
       --env ASD_SYSTEM_NAME=${ASD_SYSTEM_NAME} \
       -v `pwd`:/out \
       test /out/build_fasl_in_vm.sh

# make a zip.
# This script assumes fasls are built on this directory.
zip -u $ZIP_FILE *.fasl *.lisp

# upload
aws lambda delete-function \
    --function-name $LAMBDA_FUNC_NAME

aws lambda create-function \
    --function-name $LAMBDA_FUNC_NAME \
    --zip-file fileb://$ZIP_FILE \
    --handler "process_with_cl-json.test-parse-handler" \
    --runtime provided \
    --role $LAMBDA_ROLE \
    --layers $LAMBDA_LAYER
