-----
id: reference
title: "Reference"
content-type: page
-----

This section provides some reference information related to the default metadata of contents and assets, as well as the full documentation of the [hastysite](class:kwd) min Module.

## Default Content and Asset Metadata

The following table lists all the default metadata properties available for contents and assets, and also after which build phase they become available.

> %note%
> Note
> 
> You can define your own custom metadata for contents in a header section delimited by five dashes, at the start of each content file.

> %responsive%
> Property       | Content               | Asset            
> ---------------|-----------------------|-----------------
> id             | [](class:check)       | [](class:check)
> path           | [](class:check)       | [](class:check)
> ext            | [](class:check)       | [](class:check)
> type           | [](class:check)       | [](class:check)
> title          | [](class:check)^1     | [](class:square)
> content-type   | [](class:check)^1     | [](class:square)
> date           | [](class:check)^(1,2) | [](class:square)
> timestamp      | [](class:check)^(1,2) | [](class:square)
> contents       | [](class:check)^3     | [](class:check)^3

> %unstyled%
> * <sup>1</sup> This property is defined for all **page** and **post** contents created using the default [page](class:kwd) and [post](class:kwd) commands.
> * <sup>2</sup> This property is defined for all **post** contents created using the default [post](class:kwd) command.
> * <sup>3</sup> This property *must* be added to contents and assets before they can be written to the output folder. This can be done implicitly using symbols provided with the [hastysite](class:kwd) min module.

## [hastysite](class:kwd) min Module

This [min](https://min-lang.org) module can be imported in the [rules.min](class:kwd) file or in any script file and can be used to perform common operations such as ready and writing files, and interact with HastySite data at build time.

{{null => &#x2205;}}
{{d => [dict](class:kwd)}}
{{q => [quot](class:kwd)}}
{{m => [meta](class:kwd)}}
{{qm => [(meta<sub>\*</sub>)](class:kwd)}}
{{q1 => [quot<sub>1</sub>](class:kwd)}}
{{q2 => [quot<sub>2</sub>](class:kwd)}}
{{s => [string](class:kwd)}}
{{s1 => [string<sub>1</sub>](class:kwd)}}
{{s2 => [string<sub>2</sub>](class:kwd)}}

{#op => 
<a id="op-$1"></a>
### [$1](class:kwd) 

> %operator%
> [ $2 **&rArr;** $3](class:kwd)
> 
> $4
 #}

{#op||assets||{{null}}||{{qm}}||
Returns a quotation of metadata dictionaries {{qm}} containing the metadata of each asset file.
 #}

{#op||clean-output||{{null}}||{{null}}||
Deletes all the contents of the [output](class:dir) directory.
 #}

{#op||clean-temp||{{null}}||{{null}}||
Deletes all the contents of the [temp](class:dir) directory.
 #}

{#op||contents||{{null}}||{{qm}}||
Returns a quotation of metadata dictionaries {{qm}} containing the metadata of each content file.
 #}

{#op||input-fread||{{m}}||{{s}}||
Reads the contents of the file identified by the metadata dictionary {{m}} (such as those returned by the [contents](class:kwd) and [assets](class:kwd) parameters).

Note that:

* The source directory is determined by the value of the [type](class:kwd) metadata property.
* The path within the source directory is determined by the value of the [path](class:kwd) metadata property.
 #}

{#op||markdown||{{s1}} {{d}}||{{s2}}||
Converts the [HastyScribe](https://h3rald.com/hastyscribe) Markdown string {{s1}} into the HTML fragment {{s2}}, using the properties of {{d}} as custom fields (accessible therefore via HastyScribe's [\{\{$&lt;field-name&gt;\}\}](class:kwd) syntax).
 #}

{#op||mustache||{{s1}} {{d}}||{{s2}}||
Renders mustache template {{s1}} into {{s2}}, using dictionary {{d}} as context.

> %note%
> Note
> 
> {{s1}} is the path to the mustache template file, relative to the [templates](class:dir) directory and without [.mustache](class:ext).
 #}

{#op||output||{{null}}||{{s}}||
Returns the full path to the [output](class:dir) directory.
 #}

{#op||output-cp||{{m}}||{{null}}||
Copies a file from the source directory ([contents](class:dir) or [assets](class:dir) depending on its [type](class:kwd)) to the [output](class:dir) directory.

Note that:

* The source directory is determined by the value of the [type](class:kwd) metadata property.
* The path within the source directory is determined by the value of the [path](class:kwd) metadata property.
* The destination path within the output directory is determined by the value of concatenation of the [id](class:kwd) and [ext](class:kwd) metadata properties.
* The contents of the file are retrieved from the [contents](class:kwd) metadata property (in case of contents) or the contents of the original file (in case of assets).

 #}

{#op||output-fwrite||{{m}}||{{null}}||
Writes the contents of the file identified by the metadata dictionary {{m}} (such as those returned by the [contents](class:kwd) and [assets](class:kwd) parameters).

Note that:

* The destination path within the output directory is determined by the value of concatenation of the [id](class:kwd) and [ext](class:kwd) metadata properties.
* The contents of the file are retrieved from the [contents](class:kwd) metadata property (in case of contents) or the contents of the original file (in case of assets).

 #}

{#op||postprocess||{{null}}||{{null}}||
Starts the postprocessing phase of the build.
 #}

{#op||preprocess||{{null}}||{{null}}||
Starts the preprocessing phase of the build.
 #}

{#op||preprocess-css||{{s1}}||{{s2}}||
Pre-process [CSS variable](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_variables) declarations and usages within {{s1}}, returning the resulting CSS code {{s2}}.

For example, the following CSS code:

```
:root {
  --standard-gray: #cccccc;
}

.note {
  background-color: var(--standard-gray);  
}
```

Will be converted to the following:

```
:root {
  --standard-gray: #cccccc;
}

.note {
  background-color: #cccccc;  
}
```

> %warning%
> Limitation
> 
> Only basic support for CSS variables is provided, e.g. no fallback values are supported.
 #}

{#op||process-rules||{{null}}||{{null}}||
Starts the processing phase of the build, and interprets the [rules.min](class:file) file.
 #}

{#op||settings||{{null}}||{{d}}||
Returns a dictionary {{d}} containing all the settings defined in the [settings.json](class:file) file.
 #}

