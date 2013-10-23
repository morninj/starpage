# starpage

A utility to highlight starpages in PDF files.

Starpages are the page numbers from an original document. For instance, in 
Westlaw-created PDFs of court opinions, starpages (e.g., `*123`) indicate 
pagination in the original opinion.

This tool highlights the starpages to make the original pagination more visible.

## Installation

    # Install Perl modules
    $ sudo cpan install XML::Simple
    $ sudo cpan install CAM::PDF
    $ sudo cpan install Regexp::Assemble

    # Install MuPDF on Mac OS X 
    # (see http://www.mupdf.com/ for installation on other systems)
    $ brew install mupdf

## Use

    $ perl starpage.pl -f sample.pdf -p '\*\d+' -now

This creates an output file named `sample-highlighted.pdf`.

## Credits

See [this helpful answer to my Stack Overflow question](http://stackoverflow.com/questions/19414763/detect-and-alter-strings-in-pdfs/19551997).
