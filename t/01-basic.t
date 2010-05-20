#!/usr/bin/env perl
use Test::t;

use Path::Tree;

my ( $node, $dispatch );

$node = Path::Tree::Node->new( rule => Path::Tree::Rule::Always->new );
$dispatch = Path::Tree::Dispatch->new( path => 'a/b/c/d' );
$node->dispatch( $dispatch );
is( $dispatch->tail->leftover, 'a/b/c/d' );

$node->add( Path::Tree::Node->new( rule => Path::Tree::Rule::Regexp->new( regexp => qr/a\/b/ ) ) );
$node->dispatch( $dispatch );
is( $dispatch->tail->leftover, '/c/d' );
