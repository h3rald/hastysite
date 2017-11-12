* Ignores contents and assets starting with [.](class:kwd) or [\_](class:kwd).
* Pre-processes [CSS variables](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_variables) in all [.css](class:ext) files.
* Processes text as [HastyScribe](https://h3rald.com/hastysite)-compatible Markdown in all [.md](class:ext) content files.
* Associates contents to [mustache](https://mustache.github.io/) templates based on the value of the [content-type](class:kwd) metadata property. 
* Copies each asset file "as-is" to the [output](class:dir) directory, respecting the source directory structure in the [asset](class:dir) directory.
* Copies each content file to a directory within the [output](class:dir) named after the source content ID, in an [index.html](class:file) file (to easily obtain "pretty URLs" ending with no extension). 

