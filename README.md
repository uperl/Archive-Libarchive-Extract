# Archive::Libarchive::Extract ![linux](https://github.com/uperl/Archive-Libarchive-Extract/workflows/linux/badge.svg)

An archive extracting mechanism (using libarchive)

# SYNOPSIS

```perl
use Archive::Libarchive::Extract;

# TODO
```

# DESCRIPTION

This class provides a simple interface for extracting archives using `libarchive`.  Although it provides similar
functionality to [Archive::Extract](https://metacpan.org/pod/Archive::Extract) and [Archive::Extract::Libarchive](https://metacpan.org/pod/Archive::Extract::Libarchive) it intentionally does not provide a
compatible interface.  In particular it tends to throw exceptions instead tracking errors as a property.
It also supports some unique features of the various classes that use the "Extract" style interface:

- Many Many formats

    compressed tar, Zip, RAR, ISO 9660 images, etc.

- Zips with encrypted entries

    You can specify the passphrase or a passphrase callback with the constructor

- Multi-file RAR archives

    If filename is an array reference it will be assumed to be a list of filenames
    representing a single multi-file archive.

# CONSTRUCTOR

## new

```perl
my $extract = Archive::Libarchive::Extract->new(%options);
```

This creates a new instance of the Extract object.

- filename

    ```perl
    my $extract = Archive::Libarchive::Extract->new( filename => $filename );
    ```

    This option is required, and is the filename of the archive.

- passphrase

    ```perl
    my $extract = Archive::Libarchive::Extract->new( passphrase => $passphrase );
    my $extract = Archive::Libarchive::Extract->new( passphrase => sub {
      ...
      return $passphrase;
    });
    ```

    This option is the passphrase for encrypted zip entries, or a
    callback which will return the passphrase.

# PROPERTIES

## filename

This is the archive filename for the Extract object.

## to

The full path location the entries were extracted to.  If ["extract"](#extract) hasn't been called yet,
then this will be `undef`

# METHODS

## extract

```
$extract->extract(%options);
```

This method extracts the entries from the archive.  By default
it places them relative to the current working directory.  If
you provide the `to` option it will place them there instead.
This method will throw an exception on error.

- to

    The directory path to place the extracted entries.  Will be
    created if possible/necessary.

# SEE ALSO

- [Archive::Extract](https://metacpan.org/pod/Archive::Extract)

    The original!

- [Archive::Extract::Libarchive](https://metacpan.org/pod/Archive::Extract::Libarchive)

    Another implementation that also relies on `libarchive`, but doesn't support
    the file type in iterate mode, encrypted zip entries, or multi-file RAR archives.

- [Archive::Libarchive::Peek](https://metacpan.org/pod/Archive::Libarchive::Peek)

    An interface for peeking into archives without extracting them to the local filesystem.

- [Archive::Libarchive](https://metacpan.org/pod/Archive::Libarchive)

    A lower-level interface to `libarchive` which can be used to read/extract and create
    archives of various formats.

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
