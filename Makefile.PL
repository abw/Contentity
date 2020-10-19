use ExtUtils::MakeMaker;

my %opts = (
    NAME         => 'Contentity',
    VERSION      => 0.01,
    PMLIBDIRS    => [ 'lib' ],
    PREREQ_PM    => {
        Badger   => 0.092,
        Template => 3.000,
        'JSON'   => 2.59,
        'YAML'   => 0.84,
        'Email::Sender' => 1.3,
        'Plack::Request::WithEncoding' => 0.12,
      # 'IPC::Run' => 0,
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
