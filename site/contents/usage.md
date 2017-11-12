-----
id: usage
title: "Usage"
content-type: page
-----

HastySite is a simple command-line program that supports some default commands and options, described in the following sections. 

## Syntax

<code>
**hastysite** *command* [ *options* ]
</code>


## Default Commands

The following sections define the default commands provided by HastySite. All of them except for [init](class:kwd) can be modified, and you can also configure your own commands by creating your own [min](https://min-lang.org) scripts and placing them in the [scripts](class:dir) directory.

{#customizable-command => 
> %note%
> Note
> 
> This command can be customized by modifying the [scripts/$1.min](class:file) file within your site directory.
 #}

### build

Builds the site by preprocessing contents and assets, processing rules defined in the [rules.min](class:file) file, and creating a temporary file containing the checksums of all newly-generated files. By doing so, the next time this command is executed, only the files that have actually been modified will be copied to the [output](class:dir) directory.

The [rules.min](class:file) file processed by this command:

{@ _default-rules_.md || 1 @}

{#customizable-command||build#}

### clean

Deletes all files and directories in the [output](class:dir) and [temp](class:dir) directories.

{#customizable-command||clean#}

### init

Initializes a new HastySite site directory, by creating the following directory structure:

{@ _site-structure_.md || 1 @}


### page

Generates an empty page content file containing initial metadata. This command asks the user for the following information:

* A valid ID composed only by letters, numbers, and dashes that has not yet been used for another page.
* The title of the page.

After information has been provided, a new content will be created in the [contents](class:dir) directory containing the following metadata properties:

* id
* title
* content-type (set to **page**)

{#customizable-command||page#}

### post

Generates an empty post content file containing initial metadata. This command asks the user for the following information:

* A valid ID composed only by letters, numbers, and dashes that has not yet been used for another post.
* The title of the post.

After information has been provided, a new content will be created in the [contents/posts](class:dir) directory containing the following metadata properties:

* id
* title
* content-type (set to **post**)
* timestamp (set to the Unix timestamp of the creation of the content)
* data (set to a date string corresponding to the creation of the content)

{#customizable-command||post#}

## Options

By default, HastySite provides the following options to display information about the program or alter its behavior.

### -h, \-\-help

Displays the description of all HastySite commands and options.


### -l=_level_, \-\-loglevel=_level_

Sets the log level to one the following values:

* debug
* info
* notice (default)
* warn
* error
* fatal

### -v, \-\-version

Displays the HastySite version string.
