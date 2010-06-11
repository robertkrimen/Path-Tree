#!/usr/bin/env perl
use Test::t;

use Modern::Perl;
use Path::Tree;

my ( $tree, $declare, $node, $dispatch );

$tree = Path::Tree->new;
$declare = $tree->declare;

$node = $declare->dispatch( qr/xyzzy/ => $declare->run( sub { } ) );

ok( $node );

$tree->root->add( $declare->node( qr{a/b/c} => sub {
    diag "Xyzzy";
} ) );

$tree->root->add( $declare->node( qr{apple} =>

    sub {
        diag "Apple";
    },

    $declare->node( qr{/banana} => sub {
        diag "Apple/Banana";
    } ),

) );

$dispatch = $tree->dispatch( 'a/b/c' );
is( $dispatch->tail->leftover, '' );

$dispatch = $tree->dispatch( 'apple/banana' );

use Path::Tree::Declare( $tree = Path::Tree->new );

dispatch( qr{a/b/c} => run {
    diag "Xyzzy";
} );

dispatch( qr{apple} => 

    run {
        diag "Apple";
    },

    node( qr{/banana} => run {
        diag "Apple/Banana";
    } ),

);

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
