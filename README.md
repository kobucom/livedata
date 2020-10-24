
# Live Data Embedder

The Live Data Embedder (or just Embedder) is a simple macro processor (or template engine) for inserting dynamic data and actions in a web page.
It is a core part of an authoring and publishing environment for a data entry and viewing web application.

As other authoring tools developed in this project, Embedder is an authoring tool based on wikitext such as Markdown.
A simple marking syntax for live data and web actions are embedded in a source and converted to an Markdown source.
A live data comes from a row-by-column style data table in an SQL database.

The overall authoring and publishing system is built around a web server (such as apache).
The CGI mechanism is used to build a dynamic web page that provides live data.
The WebDav feature is used to store application source data on apache-managed directories.

## Additional Information

A brief introduction page:

- [English](https://kobu.com/livedata/index-en.html)
- [Japansese](https://kobu.com/livedata/index.html)

See Embedder section of the overall PREPRO documentation:

- [English](https://kobu.com/author/guide-en.html)
- [Japansese](https://kobu.com/author/guide.html)

See Embedder section of PREPRO syntax summary, see [syntax.html](https://kobu.com/author/syntax.html) (English).

For architecture and background behind preprocessors including Embedder, see [arch.html](https://kobu.com/author/arch.html) (English).

## Local Test

You can run Embedder locally on your PC without Apache configuration.
All you need is a Linux command line environment.
On Windows, you can use Windows Subsystem for Windows (WSL), cygwin, etc.

See `sample` directory.
It contains sample files to run the embedder locally on the linux command line.

- run-locally.sh (bash script to start frontend.cgi which in turn starts Embedder.pm)
- customer.md (test markdown source)
- sample.db (sqlite3 database file including 'customer' table)

To use the local test script, install the following packages:

- Pandoc markdown-to-html converter
- SQLite v3 (sqlite3)
- Perl interpreter
	- DBI
	- DBD::SQLite

Embedder depends on some files in the sister project, Author.
Clone the repository and run the following command:

```
$ export PREPRO_AUTHOR=/path/to/author/prepro
$ export PREPRO_DATA=/path/to/livedata/prepro
$ ./run-locally.sh
```

This emulates a view operation against /customer.md.
Other tests include edit, add, update and delete operations.
See the comments inside 'run-locally.sh' for detail.

## License

Copyright (c) 2020 Kobu.Com. Some Rights Reserved.
Distributed under GNU General Public License 3.0.
Contact Kobu.Com for other types of licenses.

## History

2020-may-09 project started  
2020-jun-05 documents for the first working implementation  
2020-aug-23 published to github
2020-oct-19 third edition
