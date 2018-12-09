-----
id: about
title: "About"
content-type: page
-----

HastySite is a static-site generator, similar to [hundreds](https://www.staticgen.com/) of others. Why bother with yet another one then?

Because HastySite:

* has been designed with minimalism in mind. It does not provide many features on its own, but it can be extended do do almost anything you'd want it to do.
* is only comprised by a single executable file, available pre-compiled for all major desktop platforms, and it can be compiled to run on even more via [Nim](https://nim-lang.org).
* embeds a concatenative programming language in it, that can be used to customize almost every aspect of it.
* can be extended, from the way it processes files to creating custom commands to do literally what you want.
* provides a simple but functional fully-working site template out-of-the-box, which is also the same template used for its [web site](https://hastysite.h3rald.com).
* provides out-of-the-box Markdown support. But not just any markdown, [HastyScribe](https://h3rald.com/hastyscribe)-compatible markdown, which extends the alredy-amazing and powerful [Discount](https://www.pell.portland.or.us/~orc/Code/discount/) engine with more useful features such as snippets, macros, fields and transclusion.
* provides a robust logic-less templating engine based on [mustache](https://mustache.github.io/).
* provides support for SCSS-like partials and [CSS variables](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_variables), which don't substitute a full fledged CSS preprocessor like LESS or SASS, but they do help.


## Technology and Credits

HastySite has been built leveraging the following open source projects:

* The [min](https://min-lang.org) programming language.
* The [HastyScribe](https://h3rald.com/hastyscribe) markdown compiler.
* The [moustachu](https://github.com/fenekku/moustachu) mustache template engine.

Special thanks also to the creators and maintainers of the following projects, that made HastySite possible:

* The [Nim](https://nim-lang.org) programming language, used to develop HastySite and all the above-mentioned projects.
* The [Discount](https://www.pell.portland.or.us/~orc/Code/discount/) markdown compiler, used as the basis for HastyScribe.

## Sites Using HastySite

HastySite powers the following web sites:

* <https://hastysite.h3rald.com>
* <https://h3rald.com>
* <https://min-lang.org>
