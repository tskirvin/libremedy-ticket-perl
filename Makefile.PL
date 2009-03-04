use ExtUtils::MakeMaker;

opendir (SCRIPTS, 'bin') or die "couldn't open 'bin': $!\n";
my @scripts = grep { /^[^\.]/ } readdir SCRIPTS;
closedir SCRIPTS;
map { s%^%bin/% } @scripts;

WriteMakefile(
    NAME              => 'Remedy::Ticket',
    DISTNAME          => 'Remedy::Ticket',
    ABSTRACT_FROM     => "lib/Remedy/Ticket.pm",
    dist              => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    VERSION_FROM      => 'lib/Remedy/Ticket.pm', 
    EXE_FILES         => \@scripts,
    AUTHOR            => 'Tim Skirvin <tskirvin@stanford.edu>',
    PREREQ_PM         => { 
      'Remedy'              => '0.01'
                         }, 
);
