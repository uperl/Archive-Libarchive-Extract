package Archive::Libarchive::Extract;

use strict;
use warnings;
use Archive::Libarchive 0.04 qw( ARCHIVE_OK ARCHIVE_WARN ARCHIVE_EOF ARCHIVE_EXTRACT_TIME ARCHIVE_EXTRACT_PERM ARCHIVE_EXTRACT_ACL ARCHIVE_EXTRACT_FFLAGS );
use Ref::Util qw( is_plain_coderef is_plain_arrayref is_plain_scalarref is_ref );
use Carp ();
use File::chdir;
use Path::Tiny ();
use 5.020;
use experimental qw( signatures postderef );

# ABSTRACT: An archive extracting mechanism (using libarchive)
# VERSION

=head1 SYNOPSIS

# EXAMPLE: examples/synopsis.pl

=head1 DESCRIPTION

This class provides a simple interface for extracting archives using C<libarchive>.  Although it provides similar
functionality to L<Archive::Extract> and L<Archive::Extract::Libarchive> it intentionally does not provide a
compatible interface.  In particular it tends to throw exceptions instead tracking errors as a property.
It also supports some unique features of the various classes that use the "Extract" style interface:

=over 4

=item Many Many formats

Tar, Zip, RAR, ISO 9660 images, gzip, bzip2, etc.

=item Zips with encrypted entries

You can specify the passphrase or a passphrase callback with the constructor

=item Multi-file RAR archives

If filename is an array reference it will be assumed to be a list of filenames
representing a single multi-file archive.

=back

=head1 CONSTRUCTOR

=head2 new

 my $extract = Archive::Libarchive::Extract->new(%options);

This creates a new instance of the Extract object.  One of the L</filename> or
L</memory> option

=over 4

=item filename

 my $extract = Archive::Libarchive::Extract->new( filename => $filename );

The filename of the archive to read from.

=item memory

[version 0.03]

 my $peek = Archive::Libarchive::Peek->new( memory => \$content );

A reference to the memory region containing the archive.  Passing in a plain
scalar will throw an exception.

=item passphrase

 my $extract = Archive::Libarchive::Extract->new( passphrase => $passphrase );
 my $extract = Archive::Libarchive::Extract->new( passphrase => sub {
   ...
   return $passphrase;
 });

This option is the passphrase for encrypted zip entries, or a
callback which will return the passphrase.

=item entry

 my $extract = Archive::Libarchive::Extract->new( entry => sub ($e) {
   ...
   return $bool;
 });

This callback will be called for each entry in the archive, and will pass in the
entry metadata via C<$e> which is a L<Archive::Libarchive::Entry> instance.  If the
callback returns a true value, then the entry will be extracted, otherwise it will
be skipped.

=back

=cut

sub new ($class, %options)
{
  Carp::croak("Required option: one of filename or memory")
    unless defined $options{filename} || defined $options{memory};

  Carp::croak("Exactly one of filename or memory is required")
    if defined $options{filename} && defined $options{memory};

  if(defined $options{filename})
  {
    foreach my $filename (@{ is_plain_arrayref($options{filename}) ? $options{filename} : [$options{filename}] })
    {
      Carp::croak("Missing or unreadable: $filename")
        unless -r $filename;
    }
  }
  elsif(!(is_plain_scalarref $options{memory} && defined $options{memory}->$* && !is_ref $options{memory}->$*))
  {
    Carp::croak("Option memory must be a scalar reference to a plain non-reference scalar");
  }

  Carp::croak("Entry is not a code reference")
    if defined $options{entry} && !is_plain_coderef $options{entry};

  my $self = bless {
    filename   => delete $options{filename},
    passphrase => delete $options{passphrase},
    entry      => delete $options{entry},
    memory     => delete $options{memory},
  }, $class;

  Carp::croak("Illegal options: @{[ sort keys %options ]}")
    if %options;

  return $self;
}

=head1 PROPERTIES

=head2 filename

This is the archive filename for the Extract object.  This will be C<undef> for in-memory archives.

=cut

sub filename ($self)
{
  return $self->{filename};
}

=head2 to

The full path location the entries were extracted to.  If L</extract> hasn't been called yet,
then this will be C<undef>

=cut

sub to ($self)
{
  return $self->{to};
}

=head2 entry_list

 my @list = $extract->entry_list;

The list of entry pathnames that were extracted.

=cut

sub entry_list ($self)
{
  return $self->{entry_list}->@*;
}

=head1 METHODS

=head2 extract

 $extract->extract(%options);

This method extracts the entries from the archive.  By default
it places them relative to the current working directory.  If
you provide the C<to> option it will place them there instead.
This method will throw an exception on error.

=over 4

=item to

The directory path to place the extracted entries.  Will be
created if possible/necessary.

=back

=cut

sub _archive ($self)
{
  my $r = Archive::Libarchive::ArchiveRead->new;
  my $e = Archive::Libarchive::Entry->new;

  $r->support_filter_all;
  $r->support_format_all;

  if($self->{passphrase})
  {
    if(is_plain_coderef $self->{passphrase})
    {
      $r->set_passphrase_callback($self->{passphrase});
    }
    else
    {
      $r->add_passphrase($self->{passphrase});
    }
  }

  my $ret;

  if(defined $self->{filename})
  {
    $ret = is_plain_arrayref($self->filename) ? $r->open_filenames($self->filename, 10240) : $r->open_filename($self->filename, 10240);
  }
  else
  {
    $ret = $r->open_memory($self->{memory});
  }

  if($ret == ARCHIVE_WARN)
  {
    Carp::carp($r->error_string);
  }
  elsif($ret < ARCHIVE_WARN)
  {
    Carp::croak($r->error_string);
  }

  return ($r,$e);
}

sub _entry ($self, $r, $e)
{
  my $ret = $r->next_header($e);
  return 0 if $ret == ARCHIVE_EOF;
  if($ret == ARCHIVE_WARN)
  {
    Carp::carp($r->error_string);
  }
  elsif($ret < ARCHIVE_WARN)
  {
    Carp::croak($r->error_string);
  }
  return 1;
}

sub extract ($self, %options)
{
  Carp::croak("Already extracted") if defined $self->to;

  my $to = Path::Tiny->new($options{to} // $CWD);
  $to->mkpath unless -d $to;

  my($r, $e) = $self->_archive;

  local $CWD = $to;

  my $dw = Archive::Libarchive::DiskWrite->new;
  $dw->disk_set_options(
    ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_ACL | ARCHIVE_EXTRACT_FFLAGS
  );
  $dw->disk_set_standard_lookup;

  while(1)
  {
    last unless $self->_entry($r, $e);
    if(defined $self->{entry} && !$self->{entry}->($e))
    {
      $r->read_data_skip;
      next;
    }

    push $self->{entry_list}->@*, $e->pathname;

    my $ret = $dw->write_header($e);
    if($ret == ARCHIVE_WARN)
    {
      Carp::carp($dw->error_string);
    }
    elsif($ret < ARCHIVE_WARN)
    {
      Carp::croak($dw->error_string);
    }

    if($e->size > 0)
    {
      my $offset;
      while(1)
      {
        my $buffer;
        $ret = $r->read_data_block(\$buffer, \$offset);
        last if $ret == ARCHIVE_EOF;
        if($ret == ARCHIVE_WARN)
        {
          Carp::carp($r->erorr_string);
        }
        elsif($ret < ARCHIVE_WARN)
        {
          Carp::croak($dw->error_string);
        }
        last unless defined $buffer;

        $ret = $dw->write_data_block(\$buffer, $offset);
        if($ret == ARCHIVE_WARN)
        {
          Carp::carp($dw->error_string);
        }
        elsif($ret < ARCHIVE_WARN)
        {
          Carp::croak($dw->error_string);
        }
      }
    }

    $ret = $dw->finish_entry;
    if($ret == ARCHIVE_WARN)
    {
      Carp::carp($dw->erorr_string);
    }
    elsif($ret < ARCHIVE_WARN)
    {
      Carp::croak($dw->error_string);
    }
  }

  $r->close;
  $dw->close;

  $self->{to} = "$to";

}

1;

=head1 SEE ALSO

=over 4

=item L<Archive::Extract>

The original!

=item L<Archive::Extract::Libarchive>

Another implementation that also relies on C<libarchive>, but doesn't support
the file type in iterate mode, encrypted zip entries, or multi-file RAR archives.

=item L<Archive::Libarchive::Peek>

An interface for peeking into archives without extracting them to the local filesystem.

=item L<Archive::Libarchive>

A lower-level interface to C<libarchive> which can be used to read/extract and create
archives of various formats.

=back

=cut

