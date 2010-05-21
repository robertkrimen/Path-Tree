#!/usr/bin/env perl
use Test::t;

use Modern::Perl;
use Path::Tree;

my ( $tree, $declare, $node, $dispatch );

$tree = Path::Tree->new;
$declare = $tree->declare;

$node = $declare->resolve_dispatch( qr/xyzzy/ => $declare->run( sub { } ) );

ok( $node );

$tree->root->add( $declare->resolve_dispatch( qr{a/b/c} => sub {
    diag "Xyzzy";
} ) );

$tree->root->add( $declare->resolve_dispatch( qr{apple} =>

    sub {
        diag "Apple";
    },

    $declare->resolve_dispatch( qr{/banana} => sub {
        diag "Apple/Banana";
    } ),

) );

#dispatch qr{apple} => chain {

#    run {
#        diag "Apple";
#    };

#    dispatch qr{/banana} => to {
#        diag "Apple/Banana";
#    };

#};

$dispatch = $tree->dispatch( 'a/b/c' );
is( $dispatch->tail->leftover, '' );

$dispatch = $tree->dispatch( 'apple/banana' );
__END__

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
