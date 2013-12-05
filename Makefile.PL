use ExtUtils::MakeMaker;

my %opts = (
    NAME         => 'Contentity',
    VERSION      => 0.01,
    PMLIBDIRS    => [ 'lib' ], 
    PREREQ_PM    => {
        Badger   => 0.092,
        'JSON::XS' => 3.01,
        'YAML::XS' => 0.41,
    },
    dist         => {
        COMPRESS => 'gzip',
        SUFFIX   => 'gz',
    },
    test         => {
        TESTS    => 't/*/*.t',
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{ AUTHOR   } = 'Andy Wardley <abw@wardley.org>';
    $opts{ ABSTRACT } = 'Web site metadata management system',
}

WriteMakefile( %opts );

