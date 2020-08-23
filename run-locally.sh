#!/bin/bash

## Test instructions:
## - First try 'view' and open output.html.
## - Second try add, update and delete in this order.

# test Embedder.pm locally
# GET:  ./run-data-cgi.sh [view|get|whatever] - read database and output html
# POST: ./run-data-cgi.sh {add|update|delete} - update database
# TEST: ./run-data-cgi.sh test                - interactive test

# default for 'view'

export DOCUMENT_ROOT=/var/www/example.com/html # not used
export REQUEST_METHOD=GET
export PATH_INFO=/sample/customer.mdm

#export DATAROOT=/var/www/dav
export DATAROOT=./data_root

export PREPRODIR=.
export DEBUG_LEVEL=1

POSTDATA=''

if [ "$1" = "add" ]; then
    export REQUEST_METHOD="POST"
    POSTDATA='__action=add&customer=kazama&phone=1111-1111&email=kazama%40example.com'
elif [ "$1" = "update" ]; then
    export REQUEST_METHOD="POST"
    export QUERY_STRING=customer=kazama
    POSTDATA='__action=update&customer=kazama&phone=9999-9999&email=kazama%40example.com'
elif [ "$1" = "delete" ]; then
    export REQUEST_METHOD="POST"
    export QUERY_STRING=customer=kazama
    POSTDATA='__action=delete&customer=kazama'
elif [ "$1" = "test" ]; then
    export QUERY_STRING=customer=suzuki
    export DEBUG_LEVEL=2
else
    export QUERY_STRING=customer=suzuki
fi

if [ "$REQUEST_METHOD" = "POST" ]; then
    echo $POSTDATA | perl $PREPRODIR/frontend.cgi
    echo '----------'
    sqlite3 ./data_root/sample/data/sample.db 'select * from customer'
else
    if [ "$DEBUG_LEVEL" = "2" ]; then
        perl $PREPRODIR/frontend.cgi
    else
        perl $PREPRODIR/frontend.cgi > output.html
    fi
fi
