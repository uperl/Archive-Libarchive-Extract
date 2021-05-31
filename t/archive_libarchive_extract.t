use Test2::V0 -no_srand => 1;
use Archive::Libarchive::Extract;
use Path::Tiny qw( path );
use File::Temp qw( tempdir );
use File::chdir;

is(
  dies { Archive::Libarchive::Extract->new },
  match qr/^Required option: filename at t\/archive_libarchiv/,
  'undef filename',
);

is(
  dies { Archive::Libarchive::Extract->new( filename => 'bogus.tar' ) },
  match qr/^Missing or unreadable: bogus.tar at t\/archive_li/,
  'bad filename',
);

is(
  dies { Archive::Libarchive::Extract->new( filename => 'corpus/archive.tar', foo => 1, bar => 2 ) },
  match qr/^Illegal options: bar foo/,
  'bad filename',
);

subtest 'extract' => sub {

  foreach my $to (undef, tempdir( CLEANUP => 1 ))
  {

    subtest "to => @{[ $to // 'undef' ]}" => sub {

      my $tarball;

      local $CWD = $CWD;

      if(defined $to)
      {
        $tarball = path('corpus/archive.tar');
        note "extracting to non-cwd $to";
        note "archive: $tarball";
      }
      else
      {
        $tarball = path('corpus/archive.tar')->absolute;
        $CWD = tempdir( CLEANUP => 1 );
        note "extracting to cwd $CWD";
        note "archive: $tarball";
      }

      my $extract = Archive::Libarchive::Extract->new( filename => "$tarball" );
      isa_ok $extract, 'Archive::Libarchive::Extract';

      ok(! do { no warnings; -d $extract->to } );

      try_ok { $extract->extract( to => $to ) };

      is(
        path($to // $CWD),
        object {
          call [child => 'archive/foo.txt'] => object {
            call slurp_utf8 => "hello\n";
          };
          call [child => 'archive/bar.txt'] => object {
            call slurp_utf8 => "there\n";
          };
        },
        'files',
      );

      ok(-d $extract->to);

    };

  }

};

done_testing;
