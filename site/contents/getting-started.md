-----
id: getting-started
title: "Getting Started"
content-type: page
-----

{{version => 1.3.10}}

## Download

You can download one of the following pre-built HastySite binaries:

> %unstyled%
> * {#release||{{version}}||macosx||macOS||x64||apple#}
> * {#release||{{version}}||windows||Windows||x64||windows#}
> * {#release||{{version}}||linux||Linux||x64||linux#}

{#release -> [](class:$5)[hastysite v$1 for $3 ($4)](https://github.com/h3rald/hastysite/releases/download/v$1/hastysite\_v$1\_$2\_$4.zip) #}

## Building from Source

Alternatively, you can build HastySite from source as follows:

1. Download and install [nim](https://nim-lang.org).
2. Download and build [Nifty](https://github.com/h3rald/nifty), and put the nifty executable somewhere in your [$PATH](class:kwd).
3. Clone the HastySite [repository](https://github.com/h3rald/hastysite).
4. Navigate to the HastySite repository local folder.
5. Run the following command to download HastySite's dependencies.
   > %terminal%
   > nifty install
7. Run the following command to compile HastySite:
   > %terminal%
   > nim c -d:release hastysite.nim

> %tip%
> Tip
> 
> You should put the compiled HastySite executable somewhere in yout [$PATH](class:kwd).

## Running HastySite

To create a new site, run the following command in an empty directory:

> %terminal%
> hastysite init

This will create the following default directory structure:

{@ _site-structure_.md || 1 @}

Then, create your first page by running the following command and specifying the page ID and Title:

> %terminal%
> hastysite page
> ID: home
> Title: Home Page
> \-\-\-\-\-
> id: home
> title: &quot;Home Page&quot;
> content-type: page
> \-\-\-\-\-
> Create page? [yes/no]: y

Finally, run the following command to generate your site contents (just an empty home page for now) and copy the default assets.

> %terminal%
> hastysite build
>    Preprocessing\.\.\.
>    Processing rules\.\.\.
>     - Writing file: output/index.html
>     - Copying: assets/fonts/SourceSansPro-Regular.woff -> output/fonts/SourceSansPro-Regular.woff
>     - Copying: assets/fonts/SourceSansPro-It.woff -> output/fonts/SourceSansPro-It.woff
>     - Copying: assets/fonts/fontawesome-webfont.woff -> output/fonts/fontawesome-webfont.woff
>     - Copying: assets/fonts/SourceCodePro-Regular.woff -> output/fonts/SourceCodePro-Regular.woff
>     - Copying: assets/fonts/SourceSansPro-Bold.woff -> output/fonts/SourceSansPro-Bold.woff
>     - Copying: assets/fonts/SourceSansPro-BoldIt.woff -> output/fonts/SourceSansPro-BoldIt.woff
>     - Writing file: output/styles/hastysite.css
>     - Writing file: output/styles/site.css
>     - Writing file: output/styles/luxbar.css
>     - Writing file: output/styles/hastyscribe.css
>     - Writing file: output/styles/fonts.css
>    Postprocessing\.\.\.
>    All done.

That's it! You can view the result by serving the [output](class:dir) directory from any web server.
