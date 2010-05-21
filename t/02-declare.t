#!/usr/bin/env perl
use Test::t;

use Modern::Perl;
use Path::Tree;

ok( 1 );

my ( $tree, $rule, $node, $dispatch );

use Path::Tree::Declare( $tree = Path::Tree->new );

dispatch qr{a/b/c} => to {
    diag "Xyzzy";
};

dispatch qr{apple} => chain {

    run {
        diag "Apple";
    };

    dispatch qr{/banana} => to {
        diag "Apple/Banana";
    };

};

$dispatch = $tree->dispatch( 'a/b/c' );
is( $dispatch->tail->leftover, '' );

$dispatch = $tree->dispatch( 'apple/banana' );
