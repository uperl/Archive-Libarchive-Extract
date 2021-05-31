# Archive::Libarchive::Extract ![linux](https://github.com/uperl/Archive-Libarchive-Extract/workflows/linux/badge.svg)

An archive extracting mechanism (using libarchive)

# SYNOPSIS

```perl
use Archive::Libarchive::Extract;

# TODO
```

# DESCRIPTION

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

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
