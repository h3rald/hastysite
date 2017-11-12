-----
id: customization
title: "Customization"
content-type: page
-----

By default, HastySite provide all the scripts and rules necessary to build a simple blog with static pages and timestamped blog posts. While this may work for a simple blogging site, you may need additional features like support for tags, or maybe group articles by months, or project pages with custom metadata, and so on.

HastySite can be customized to your heart content essentially in the following ways:

* By modifying the [rules.min](class:file) file and tweak the build pipeline.
* By creating custom scripts to create generators for custom content types, or any other task you deem useful for your use case.
* By leveraging HastyScribe advanced features for content reuse, like snippets, fields, macros, and transclusions.

## Default Build Pipeline

Before diving into customization techniques, you should be familiar with the way HastySite builds your site out-of-the-box. If you have a look at the [scripts/build.min](class:file) file, it looks like this:

```
;Builds a site by processing contents and assets.
'hastysite import

"Preprocessing..." notice
preprocess
"Processing rules..." notice
process-rules
"Postprocessing..." notice
postprocess
"All done." notice
```

Even if you are not familiar with the [min](https://minl-lang.org) programming language, this code looks straightforward enough. as part of the build process, three actions are performed:

1. preprocess
2. process-rules
3. post-process

### Preprocess

During this phase, the following operations are performed:

1. Some maintenance of temporary files is performed, e.g. the [temp](class:dir) directory is created and populated with a [checksums.json](class:file) file if needed, temporary contents from the previous build are deleted, and so on.
2. All contents are loaded, and metadata in the content header is processed and saved in memory.
3. All assets are loaded and bare-bones metadata is generated for them and saved in memory, as they have no header.

If you are wondering what this content header is, it's a section at the start of a content file delimited by five dashes, and containing metadata properties, like this:

```
-----
id: getting-started
title: "Getting Started"
content-type: page
-----
```

Now, this *looks* like [YAML](http://yaml.org/), but it is actually Nim's own [configuration file format](https://nim-lang.org/docs/parsecfg.html), which is a bit more limited, but it does the job. Just remember to wrap strings with spaces in double quotes and everything will be good.

Internally, after the preprocessing phase all contents and assets will have the following metadata:

id
: An identifier for the content or asset, corresponding to the path to the file relative to the [contents](class:dir) or [assets](class:dir) folder, without extension.
path
: The path to the file relative to the [contents](class:dir) or [assets](class:dir) folder, *including* extension.
type
: Either **content** or **asset**.
ext
: The file extension (including the leading [.](class:kwd)).

### Process Rules

In this phase, the control of the build process is passed to the [rules.min](class:file) script. It is important to point out that in case of an empty [rules.min](class:file) file, *nothing* will be done and no output file will be generated.

Luckily, a default [rules.min](class:file) file is provided, which:

{@ _default-rules_.md || 1 @}

Typically, you only need to modify this file to change how HastySite builds your site.

### Postprocess

In this phase, the [temp/checksums.json](class:file) is updated with the latest checksums of the generated output files.

## Modifying the [rules.min](class:kwd) File

The [rules.min](class:kwd) file is used to build your site. This file is nothing but a [min](https://min-lang-org) script, and therefore you should have at least a basic understanding of the min programming language before diving in and modifying it.

In particular, you should get acquainted with the following min modules, whose symbols and sigils are typically used to create [rules.min](class:kwd) files:

* [lang](https://min-lang.org/reference-lang/)
* [seq](https://min-seq.org/reference-seq/)
* [str](https://min-str.org/reference-str/)
* [time](https://min-time.org/reference-time/)

Additionally, a dedicated [hastysite](class:kwd) module is also provided specifically for HastySite, which is described in the Reference section.

## Creating Commands

Once you are comfortable with witing min scripts and maybe after you modified the [rules.min](class:file) file, you could try modifying or adding new HastySite commands. To do so, you must:

1. Create a new [.min](class:ext) file named after your command (e.g. [project.min](class:file)) and place it in the [scripts](class:dir) folder of your site.
2. On the first line, enter a min comment corresponding to the description of your command. This description will be used by HastySite help system.
3. On the subsequent lines, write the logic of your command in min.

For more information and examples, have a look at the default scripts generated by the <samp>hastysite init</samp> command.

## Leveraging HastyScribe Advanced Features

In some cases, you may not even need to edit [.min](class:kwd) files to customize the way your site pages are rendered. In particular, [HastyScribe](https://h3rald.com/hastyscribe), the Markdown engine that powers HastySite, provide a lot of extra feature aimed at improving content reuse, such as:

* [Transclusion](https://h3rald.com/hastyscribe/HastyScribe_UserGuide.htm#Transclusion), to basically load the contents of a Markdown file into another.
* [Snippets](https://h3rald.com/hastyscribe/HastyScribe_UserGuide.htm#Snippets), to reuse chunks of text in the same file (and transcluded files).
* [Fields](https://h3rald.com/hastyscribe/HastyScribe_UserGuide.htm#Fields), to specify things like current date and time, but also custom properties defined at run time.
* [Macros](https://h3rald.com/hastyscribe/HastyScribe_UserGuide.htm#Macros), to create chunks of reusable text with placeholders.

