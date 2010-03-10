#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

package t0;

package main;

use Path::Walker::Dispatcher;

my ( $dispatcher );

$dispatcher = Path::Walker::Dispatcher->new( class_base => 't0' );

ok( $dispatcher );
ok( $dispatcher->class_namespace );

