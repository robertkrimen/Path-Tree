#!/usr/bin/env perl
use Test::t;

use Modern::Perl;
use Path::Tree;

my ( $tree, $declare, $parse, $node, $dispatch );

use Path::Tree::Declare( $tree = Path::Tree->new );

$declare = $tree->declare;
$parse = $tree->parse;

ok( $tree );
ok( $parse );

sub always (&) {
    return $declare->node( $declare->always => @_ );
}

$tree->root->add( $parse->parse_node_children([

    qr/xyzzy/ => then {
        diag 'Xyzzy!';
    },

    run {
        diag 'After Xyzzy!';
    },

    qr/tt/ => then {
        diag 'tt';
    },

    qr/markdown/, => then {
        diag <<_END_;
<!doctype html>
<html>
*Hello*, **WORLD**
</html>
_END_
    },

    qr/api/ => [

        qr#/help# => then {
            diag "Usage: $0";
        },
    ],

    always {
        diag 'Hello, World.';
    },

]) );

$dispatch = $tree->dispatch( 'xyzzy' );
$dispatch = $tree->dispatch( 'tt' );
$dispatch = $tree->dispatch( 'a/b/c' );
