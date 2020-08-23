# Sample Markdown Source for Live Data Embedder

This page uses 'customer' table in an sqlite3 database file, 'sample.db'.

## Customer List

| Customer | Phone | Email | |
|--|--|--|--|
$| ${customer} | ${phone} | ${email} | ${!edit} |$

## Current customer: ${customer}

$form$

Customer: ${?customer}

Phone: ${?phone}

Email: ${?email}

${!update}  ${!delete}

${!add}  ${!reset}

$end$
