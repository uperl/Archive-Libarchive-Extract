package Archive::Libarchive::Extract;

use strict;
use warnings;
use Archive::Libarchive 0.03 qw( ARCHIVE_OK ARCHIVE_WARN ARCHIVE_EOF ARCHIVE_EXTRACT_TIME ARCHIVE_EXTRACT_PERM ARCHIVE_EXTRACT_ACL ARCHIVE_EXTRACT_FFLAGS );
use Ref::Util qw( is_plain_coderef is_plain_arrayref );
use Carp ();
use File::chdir;
use Path::Tiny ();
use 5.020;
use experimental qw( signatures );

# ABSTRACT: An archive extracting mechanism (using libarchive)
# VERSION

=head1 SYNOPSIS

# EXAMPLE: examples/synopsis.pl

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

 my $extract = Archive::Libarchive::Extract->new(%options);

This creates a new instance of the Extract object.

=over 4

=item filename

 my $extract = Archive::Libarchive::Extract->new( filename => $filename );

This option is required, and is the filename of the archive.

=item passphrase

 my $extract = Archive::Libarchive::Extract->new( passphrase => $passphrase );
 my $extract = Archive::Libarchive::Extract->new( passphrase => sub {
   ...
   return $passphrase;
 });

This option is the passphrase for encrypted zip entries, or a
callback which will return the passphrase.

=back

=cut

sub new ($class, %options)
{
  Carp::croak("Required option: filename")
    unless defined $options{filename};

  foreach my $filename (@{ is_plain_arrayref($options{filename}) ? $options{filename} : [$options{filename}] })
  {
    Carp::croak("Missing or unreadable: $filename")
      unless -r $filename;
  }

  my $self = bless {
    filename   => delete $options{filename},
    passphrase => delete $options{passphrase},
  }, $class;

  Carp::croak("Illegal options: @{[ sort keys %options ]}")
    if %options;

  return $self;
}

=head1 PROPERTIES

=head2 filename

This is the archive filename for the Extract object.

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

  my $ret = is_plain_arrayref($self->filename) ? $r->open_filenames($self->filename, 10240) : $r->open_filename($self->filename, 10240);

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
      my $buffer;
      while(1)
      {
        $ret = $r->read_data(\$buffer);
        last if $ret == 0;
        if($ret == ARCHIVE_WARN)
        {
          Carp::carp($r->erorr_string);
        }
        elsif($ret < ARCHIVE_WARN)
        {
          Carp::croak($dw->error_string);
        }

        $ret = $dw->write_data(\$buffer);
        if($ret == ARCHIVE_WARN)
        {
          Carp::carp($dw->erorr_string);
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
