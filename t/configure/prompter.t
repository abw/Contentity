#============================================================= -*-perl-*-
#
# t/configure/prompter.t
#
# Test the Contentity::Prompter module
#
# Copyright (C) 2014 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib    => '../../lib',
    Utils  => 'Bin',
    Debug  => [import => ':all'];

use Badger::Test
    tests => 1,
    debug => 'Contentity::Prompter',
    args  => \@ARGV;

use Contentity::Prompter;

my $pr = Contentity::Prompter->new;
ok( $pr, 'created prompter' );

if (DEBUG) {
    print $pr->colourise(
        "Hello world this is [red:RED], [green:GREEN] and [blue:some blue text]\n",
    );

    $pr->prompt_about("A message prompt");
    print "\n";
    $pr->prompt_comment("A comment prompt");
    $pr->prompt_error("An error prompt");
    $pr->prompt_options(['foo', 'bar','baz']);
    $pr->prompt_dry_run("Something in a dry run");
    $pr->prompt_dry_run_cmd("rm * # only joking");
    $pr->prompt(
        "Your favourite cheese",
        "cheddar",
        mandatory => 1,
        comment   => 'Please enter your favourite kind of cheese.',
        options   => ['brie', 'cheddar', 'stilton'],
    );

}
