#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

use Path::StepDispatcher;

my $builder = Path::StepDispatcher::Builder->new;

{
    is( Path::StepDispatcher::Rule::Regexp->new( regexp => qr/apple\/?/ )->match( 'apple/banana' )->{leftover_path}, 'banana' );
}

sub path (@) {
    return $builder->parse_switch( @_ );
}

{
    my @sequence;

    my $dispatcher = Path::StepDispatcher->new( root => path, visitor => sub {
        my $ctx = shift; 
        push @sequence, shift;
    } );

    $dispatcher->root->add(
        path( qr/apple\/?/, 'Apple' ),
    );

    $dispatcher->dispatch( "apple" );

    cmp_deeply( \@sequence, [qw/ Apple /] );
}

{
    my $root = path( undef,
        path( qr/apple\/?/,
            'Apple',
            path( qr/banana\/?/, 
                'Apple+Banana',
            ),
            sub {
                my $ctx = shift;
                $ctx->path( 'grape' ) if $ctx->path; # Always goes to the grape branch
            },
            path( qr/cherry\/?/, 
                'Apple+Cherry',
            ),
            path( qr/grape\/?/, 
                'Apple+Grape',
            ),
        ),
    );

    my @sequence;
    my $dispatcher = Path::StepDispatcher->new( root => $root, visitor => sub {
        my $ctx = shift; 
        my $data = shift;
        if ( ref $data eq 'CODE' ) {
            $data->( $ctx );
        }
        else {
            push @sequence, $data;
        }
    } );
    
    undef @sequence;
    $dispatcher->dispatch( "apple" );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    undef @sequence;
    $dispatcher->dispatch( "apple/banana" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Banana /] );

    undef @sequence;
    $dispatcher->dispatch( "cherry" );
    cmp_deeply( \@sequence, [] );

    undef @sequence;
    $dispatcher->dispatch( "apple/cherry" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Grape /] );
}

