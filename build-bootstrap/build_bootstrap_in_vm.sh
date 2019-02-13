#!/bin/sh

BIN_NAME="bootstrap"

/usr/local/bin/sbcl \
    --non-interactive \
    --load "/work/ql_libs_at_docker_build.lisp" \
    --load "/aws-lambda-runtime/aws-lambda-runtime.asd" \
    --eval "(asdf:load-system :aws-lambda-runtime)" \
    --eval "(sb-ext:save-lisp-and-die \"$BIN_NAME\" :executable t :toplevel 'aws-lambda-runtime::bootstrap)"

zip /out/aws_lambda_bootstrap.zip $BIN_NAME

rm $BIN_NAME
