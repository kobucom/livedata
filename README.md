
# Live Data Embedder

2020-may-09 project started  
2020-jun-05 documents for the first working implementation  
2020-aug-23 published to github

The Live Data Embedder (or just Embedder) is a simple macro processor (or template engine) for inserting dynamic data and actions in a web page.
It is a core part of an authoring and publishing environment for a data entry and viewing web application.

As other authoring tools developed in this project, Embedder is an authoring tool based on wikitext such as Markdown.
A simple marking syntax for live data and web actions are embedded in a source and converted to an Markdown source.
A live data comes from a row-by-column style data table in an SQL database or data file such as CSV or DBM.

The overall authoring and publishing system is built around a web server (such as apache).
The CGI mechanism is used to build a dynamic web page that provides live data.
The WebDav feature is used to store application source data on apache-managed directories.

A brief introduction is at the following page:  
[kobu.com/livedata](https://kobu.com/livedata/index-en.html)

This document includes the following three parts:

- Guide: Overview of Live Data Embedder
- Reference: Syntax rules of Embedder
- Setup: Hints for building a publishing environment using Embedder

# PART ONE: Guide

## Introduction

With the Live Data Embedder, you can build a simple data entry and viewing web application without using a programming language such as Javasript, PHP or Python.

All you have to do is to write a simple Markdown text.
When a user accesses your application, the Markdown file will be converted to a dynamic web application page.
You embed a special markings called macros to indicate how your application data is entered, viewed and updated.

Example applications include:

- accept an order for some fixed items; not a full-fledge shopping cart,
- booking or reservation of places, delivery or meeting
- questionaire and survey
- simple group communication such as a bulletin board
- publication of research data in a row-by-column style
- etc.

## How Embedder Works

The Live Data Embedder is a preprocessor run as a filter or handler under Apache web server for each page request.

The Embedder allows reading and writing of pieces of data using *macros* within a text source.

It reads a source text and dynamically replaces a special markings called **macro variable** with a value stored in a **data table** such as an SQL database table a CSV file.

There is another type of macro called **button macro**.
You can embedd button macros in the source text to allow the user to view a list of data, type and submit new data, and update and delete the data.

## Data Table

The Embedder allows you to handle data in a row-by-column table.
This is called **data table**.

Example data table:

| Date | Customer | Apple | Orange | Kui |
|--|--|--|--|--|
| 20-05-01 | yamada | 10 | 10 | 0 |
| 20-05-03 | suzuki | 10 | 0 | 10 |
| 20-05-10 | yamada | 0 | 0 | 20 |

With an Embedder-based application, you can:

- view list of rows
- view columns of a row
- enter a new row of data
- update column data of a row
- delete a row

## List View

In Markdown you write an HTML table using vertical bars (|).
When using the Embedder, you can write a single line of a table row *template* used to render every row in a database table.

Change the first vertical bar with `$|` and the last one to `|$` to indicate that row is a row template.

```
| Date | Customer | Apple | Orange | Kui | |
|--|--|--|--|--|--|
$| ${date} | ${customer} | ${apple} | ${orange} | ${kui} | ${!edit} |$
```

A syntax of the form ${*name*} is called a **display variable** and denotes a value of *name* of a row should be displayed in place of it.

If the data table contains multiple rows, column values of each row are displayed.
The row template produces the following output:

| Date | Customer | Apple | Orange | Kui | |
|--|--|--|--|--|--|
| 20-05-01 | yamada | 10 | 10 | 0 | [Edit] |
| 20-05-03 | suzuki | 10 |  0 | 10 | [Edit] |
| 20-05-10 | yamada |  0 |  0 | 20 | [Edit] |

## Individual View

An HTML form is used to send items of data to the web server.
The following construct is an Embedder way of describing an HTML form.
It can be used to write a row of data to a data table on the server.

```
$form$

Date: ${?date}
Name: ${?customer}

Apple: ${?apple}
Orange: ${?orange}
Kui: ${?kui}

${!update}  ${!delete}
${!add}     ${!reset} 

$end$
```

The `$forms` and `$end$` markers indicate lines between them should be handled by Embedder to construct an HTML form suitable for data table operation.

The syntax of ${?*name*} (a question mark in front of the name) is called **entry variable** or entry macro and it will be replaced with an HTML input field of the value.

The ${!*action*} is one type of button macro and called **action macro**.
It corresponds to a submit button in an HTML form or a link button elsewhere in the page.
Clicking this button requests an action on the web server and a page is reloaded.
Page actions include: add, update, delete, edit and reset.

The above form will look like:

```
Date: [          ]
Name: [          ]

Apple:  [          ]
Orange: [          ]
Kui:    [          ]

[Update]  [Delete]
[Add]     [Reset]
```

# PART Two: Reference

This part describes syntax of:

- macro variable
- action macro

and details of:

- data table
- data store

and some rules about page, file or table names.

## Macro Syntax

A macro of the Live Data Embedder can take either of the following formats:

| Macro | Syntax | Description |
|--|--|--|
| Display variable | ${variable} | shows a value of a variable |
| Entry variable | ${?variable} | renders an input field for a variable |
| Action macro | ${!action} | show a button to perform an action |

There are two major categories in embedder macros.
The first two macros are *variables* while the last one is called a *button*.

In all cases, a macro starts with a pair of dollar sign ($) and opening bracket ({) and ends with a closing bracket (}).

## Display Variable

The first and second forms above are called macro variables.
${*variable*} is called *display variable*.
It is used to embed a current value of the variable in a web page.

A variable name consists of one or more alphabet or numeric characters plus underscore (_).

Examples:

- ${phone}
- ${phone_number}
- ${phone2}

## Entry Variable

The second form, ${?*variable*} is called *entry variable*.
Note that a question mark (?) appears in front of the variable name.
It is used to let a web client user enter a value for the variable.

### Entry types

All data used in an Embedder application is a text string.
Every data item is shown as a text string and entered as a text string.
Even a number or date is stored in a data table as a text string.

Examples of text strings:

- "hello"
- "100"
- "23.4"
- "2020-05-11"
- "09:24:18am"

An entry macro is converted in the following way:
```
 Enter the number of apples: ${?apple}
   |
   v
 Enter the number of apples: <input type="text" name="apple" value="10"></input>
```

If you want to use a different entry style than a text input field, you can specify an **entry type** for a data column.

Currently available types are:

- text (default)
- password
- email
- date
- time
- number
- checkbox
- radio
- select (and option)

An entry type can be specified for an entry variable by adding a slash (/) followed by the type as in:

```
${?entry_variable/entry_type}
```

Examples:
```
${?customer/email}
${?password/password}
${?order_date/date}
```

The default entry type is 'text' and 
${?remark} is the same as ${?remark/text}. 


Of these, radio and select are special in that they require a list of candidate values.
This is called **value list** and represented by a comma-separated list of words:

Examples:
- 'yes,no'
- 'apple,orange,kui,melon'

A value list can be specified by adding a further slash (/) followed by the list as in:

```
${?entry_variable/select_or_radio/value_list}
```

Examples:
```
${?marriage/radio/single,married}
${?desert/select/apple,orange,kui,memon}
```

### Action Macro

The third form above is called action macro.
An action macro is marked with an exclamation mark (!) right after the opening bracket ({).

```
${!action}
```

An action macro does not represent a value but designate an action to occur when the browser user clicks it.
It is shown as a button on an HTML page.
Clicking the button requests some action on the web server and load a new page (same or different).

> Action macro is one type of button macros and also called action button.

There are two types of action macros.
A submit button of an HTML form or a link button elsewhere in a page.
There exists a limited number of action macros.

| Action | Macro | Position | Description |
|--|--|--|--|
| Add | ${!add} | Form | Add a new row of data |
| Update | ${!update} | Form | Update one or more columns of an existing row |
| Delete | ${!delete} | Form | Delete a row |
| Edit | ${!edit} | Anywhere | Select a row for editing |
| Reset | ${!reset} | Anywhere | Reset row selection. This allows entry of a new row (add) |

### Extra Embedder-Special Syntaxes

Embedder recognizes the following markings as beginning and end of some special handling:

| Marking | Description |
|--|--|
| `$form$` | Start of HTML form |
| `$end$` | End of form |
| `$|` | Start of HTML table row template |
| `|$` | End of row template |

## Data Table

A set of data is organized in a row-by-column table called **data table**.

A **data store** contains one or more related data tables.

Example:

| Customer | Phone | Email |
|--|--|--|
| yamada | 1234-5678 | yamada@example.com |
| suzuki | 8765-4321 | suzuki@example.com |

The first column, in this case 'customer', is special and used to identify a row.
It is called **id** column or field and corresponds to a primary key in SQL database table.

While the Embedder runs, there is always the **current row**.
The current row determines what value a macro variable will take.
The value of the id field, in this case 'customer', determines the current row.

For example, if the current value of 'customer' is 'suzuki' the current row is the second line.
Therefore 'phone' is '8765-4321' and 'email' is 'suzuki@example.com'.

TODO: Note about table row case

## Data Store

The previous section describes an abstract data expression based on a row-by-column table.

A data store, set of related data tables, can be implemented in several different ways.
Any type of data store can be used with Embedder if it supports row-by-column semantics.
More than one type of data store can be used at the same time.

The current version of Embedder uses tables in an SQL database file backed by **sqlite3**.
The earliest implementation used a text file (a tab-separated file).

### Text Files

A data table can be stored in a CSV or tab-separated file. One or more CSV files are used to represent a data store for an application.

A data table named 'customer' is stored in 'customer.csv'.
The example table above can be stored in a CSV file as follows:

```
[customer.csv]
# customer, phone, email
"yamada", "1234-5678", "yamada@example.com" 
"suzuki", "8765-4321", "suzuki@example.com"
 ...
```

### SQL database

An SQL database can be used as a data store.
Embededder can access an SQL table in the database as a data table.

Here are SQL statements for creating and a data table and populating records with it.

```
CREATE TABLE customer (
	customer TEXT PRIMARY KEY NOT NULL,
	phone TEXT,
	email TEXT
);

INSERT INTO customer (customer, phone, email)
VALUES("yamada", "1234-5678", "yamada@example.com"); 
INSERT INTO customer (customer, phone, email)
VALUES("suzuki", "8765-4321", "suzuki@example.com"); 
 ...
```

Note that both the table name and the id field name are 'customer'.
This is a convension in Embedder although not mandatory.

### Key-Valure Store

A data table can be stored in a key-value or KV store such as a DBM file.
A KV store does not itself has a row-by-column format required by Embedder's data store.
A key can be composed to hold an id value and column name to point to a column value: *id-value*.*column-name*=*column-value*.

Example:
- yamada.phone="1234-5678" 
- suzuki.email="suzuki@example.com"

### Virtual Tables and Page Variables

A data table may or may not have a backing data store.

There are three types of 'virtual' data:

- Virtual table
- Calculated or side-effect table
- Page variables

Virtual table:

Reading a data value can return a value not stored in a physical table but somewhere else on the server.
Writing a data value can cause some change in state of the server.

Calculated or side-effect table:

Even if a data table has a backing data store, a read value can be a calculated value from one or more columns of a physical table.
Writing a value to a table column can also cause a side effect such as a change in some system settings.
This is similar to a *property* in some programming languages.

Page variables:

A page variable is a special and embedder-defined read-only virtual data.
It returns an internal state value, web request state value or some calculated value.
Examples are current data and time or name of an authenticated user.

## Names of Pages, Tables and Files

When building an Embedder-based web application, you must stick to its naming rules.

The following names are used in an Embedder application:

- account name (synonym for application or database name)
- table name

The application name is important.
It is used in the following names:

- first part of a URL path
- database name

The table name further determines the following names:

- URL for accessing a table
- markdown source for editing/viewing a table

For example, an 'foo' application that use 'order' table will use:

| Name | Format | URL | Path |
|--|--|--|--|
| Entry URL | /*account*/ | http://example.com/foo/ | /var/www/dav/foo/ |
| Page access URL | /*account*/*table*.mdm | http://example.com/foo/order.mdm | /web/dav/foo/data/order.md |
| Database name | *account*.db | | /web/dav/foo/data/foo.db |

For example, if the browser user wants to visit an access page for table 'order' of 'foo' application, the user points to 'http://example.com/foo/order.mdm'.
This instructs the embedder to parse a markdown source in /var/www/dav/foo/data/order.md and read the 'order' table in /var/www/dav/foo/data/foo.db database.

# PART THREE: Setup

Requirements of an environment that can run the Live Data Embedder are:

- Web server that can host a perl CGI script
- Data store accessible via Perl DBI interface
- Markdown-to-HTML converter
- Webdav if you want to place source and data files remotely

The rest is a brief memo of how to setup an environment that can host an Embedder application.

For someone who just wants to run the embedder on the command line on your local PC, see **Local Test** at the end of this page.

## Example Configuration

An example configuration I tested:

- Debian 10
- Apache web server with CGI and Webdav modules
- SQLite v3 (sqlite3)
- Pandoc markdown-to-html converter

### Apache

Install a latest version of apache web server and enable the following modules:

- webdav
- cgid

> Under apache, in addition to the plain old CGI module (mod_cgid) which loads a script every time a request comes, you have some options to make the script resident on memory such as: perl CGI script wrapper (mod_perl) or Fast CGI script module (mod_fcgid).

### Perl

Install a latest version of perl and the following packages:

- DBI
- DBD::SQLite

### sqlite3

Any type of row-by-column style data store can be used with Embedder: a database or text file.
The the current version of Embedder uses DBI, a universal SQL interface package.
DBI supports many types of data store such as SQLite, mysql, CSV or DBM.
The the current version of Embedder uses sqlite3.

Install sqlite3 library.
It may be convenient to also install sqlite3 command line executable.

### Pandoc

Install Pandoc.

## Folder Configuration

An example folder configuration could be:

- /var/www/dav - Webdav top
- /var/www/dav/guest - top folder for 'guest' account (or applicaiton)
- /var/www/dav/guest/data - Database and markdown sources for 'guest' app
- /usr/local/prepro - embedder scripts such as Embedder.pm
- /var/www/cgi-bin - CGI scripts such as frontend.cgi

Common static resources, such as a CSS are placed in the top folder (/var/www/dav).
App-specific static resources, such as HTML and image files are placed under the account folder (/var/www/dav/guest and below).
A special folder named 'data' (/var/www/guest/data) holds a database and markdown sources.
This folder should be hidden from the public.

All the embedder perl scripts can be placed in one directory.
A frontend CGI script can be used to parse CGI request parameters, setup runtime environment and call the embedder (Embedder.pm).
A sample file, `frontend.cgi`, can be used for this perpose.

## Apache Configuration

An apache handler should be setup to run embedder.
For example, the following configuration instructs to run embedder when a non-existent file of extension '.mdm' is referenced.

```
ScriptAlias /cgi-bin /var/www/cgi-bin
AddHandler live-data-text .mdm
Action live-data-text /cgi-bin/frontend.cgi virtual
Alias /guest /var/www/dav/guest
```

Some system-dependent folder locations should be specified to run the sample CGI, frontend.cgi.

```
SetEnv PREPRODIR /usr/local/prepro
SetEnv WEBDAV_ROOT /var/www/dav
```

In this configuration, if the browser request '/guest/customer.mdm' the frontend.cgi passes 'customer.md' to the embedder after opening 'guest.db' database file both in '/var/www/dav/guest/data'.

## Local Test

You can run Embedder locally on your PC without Apache configuration.
All you need is a Linux command line environment.
On Windows, you can use Windows Subsystem for Windows (WSL), cygwin, etc.

Test files used to run the embedder locally on the linux command line are included:

- run-locally.sh (bash script to start frontend.cgi which in turn starts Embedder.pm)
- data_root/sample/data/customer.md (test markdown source)
- data_root/sample/data/sample.db (sqlite3 database file including 'customer' table)

To use the local test script, install packages described in 'Example Configuration' except Apache.

```
$ cd /path/to/embedder
$ ./run-locally
```

This emulates a view operation against /sample/customer.md.
Other tests include add, update and delete operations.
See the comments inside 'run-locally.sh' for detail.
