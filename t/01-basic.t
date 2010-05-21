#!/usr/bin/env perl
use Test::t;

use Path::Tree;

my ( $tree, $rule, $node, $dispatch );

$tree = Path::Tree->new;

$rule = $tree->build_rule( 'Always' );
is( ref $rule, 'Path::Tree::Rule::Always' );

$rule = $tree->rule( qr/xyzzy/ );
is( ref $rule, 'Path::Tree::Rule::Regexp' );

$node = $tree->root->branch( qr/a\/b/ );

$dispatch = $tree->dispatch( 'a/b/c/d' );
is( $dispatch->tail->leftover, '/c/d' );



$node = Path::Tree::Node->new( rule => Path::Tree::Rule::Always->new );
$dispatch = Path::Tree::Dispatch->new( path => 'a/b/c/d' );
$node->dispatch( $dispatch );
is( $dispatch->tail->leftover, 'a/b/c/d' );

$node->add( Path::Tree::Node->new( rule => Path::Tree::Rule::Regexp->new( regexp => qr/a\/b/ ) ) );
$node->dispatch( $dispatch );
is( $dispatch->tail->leftover, '/c/d' );





