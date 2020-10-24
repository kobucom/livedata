# Sample Markdown Source for Live Data Embedder

This page uses 'customer' table in an sqlite3 database file, 'sample.db'.

## Page Information

Method: $(.method)  
Path: $(.path)  
Table: $(.table)  
Action: $(.action)  
Date: $(.datetime)

## Customer List

| Customer | Phone | Email | |
|--|--|--|--|
$| $(customer) | $(phone) | $(email) | $(!edit) |$

## Entry Form

Current customer: $(customer)

$form$

Customer: $(?customer)

Phone: $(?phone)

Email: $(?email)

$(!update)  $(!delete)

$(!add)  $(!reset)

$end$

