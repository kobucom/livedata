#!/bin/bash

# Test script to run frontend.cgi (which then calls Embedder.pm) locally
# GET:  ./run-locally.sh {view|edit}         - read database and output html
# POST: ./run-locally.sh {add|update|delete} - update database and show table content

# test hints
# 1. try 'view' and check output.html if the table rows are filled with data
# 2. try 'edit' and check output.html if the form is filled data
# 3. try add, update and delete in this order and check the table content

export DEBUG_LEVEL=1

# environment

export PREPRO_DATA=../prepro
export DOCUMENT_ROOT=.
export DBPATH=./sample.db

# request

export PATH_INFO=/customer.md

if [ "$1" = "add" ]; then
    export REQUEST_METHOD="POST"
    export QUERY_STRING=''
    POSTDATA='__action=add&customer=kazama&phone=1111-1111&email=kazama%40example.com'
elif [ "$1" = "update" ]; then
    export REQUEST_METHOD="POST"
    export QUERY_STRING='customer=kazama'
    POSTDATA='__action=update&customer=kazama&phone=9999-9999&email=kazama%40example.com'
elif [ "$1" = "delete" ]; then
    export REQUEST_METHOD="POST"
    export QUERY_STRING='customer=kazama'
    POSTDATA='__action=delete&customer=kazama'
elif [ "$1" = "edit" ]; then
    export REQUEST_METHOD=GET
    export QUERY_STRING='__action=edit&customer=suzuki'
    POSTDATA=''
else # GET
    export REQUEST_METHOD=GET
    export QUERY_STRING='customer=suzuki'
    POSTDATA=''
fi

if [ "$REQUEST_METHOD" = "POST" ]; then
    echo $POSTDATA | perl frontend.cgi > output.html
else
    perl frontend.cgi > output.html
fi

sqlite3 sample.db 'select * from customer'
