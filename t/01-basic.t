#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

use Path::StepDispatcher;

{
    is( Path::StepDispatcher::Rule::Regexp->new( regexp => qr/apple\/?/ )->match( 'apple/banana' )->remaining_path, 'banana' );
}

sub path(@) {
    my $rule = shift;
    $rule = Path::StepDispatcher::Rule::Regexp->new( regexp => $rule ) if $rule;
    my $branch = Path::StepDispatcher::Switch->new( rule => $rule );
    $branch->add( $_ ) for @_;
    return $branch;
}

sub item($) {
    my $data = shift;
    return Path::StepDispatcher::Item->new( data => $data );
}

sub action(&) {
    return item( @_ );
}

sub interrupt(&) {
    my $data = shift;
    return item( $data );
}

{
    my @sequence;

    my $ctx = Path::StepDispatcher::Context->new( visitor => sub {
        my $self = shift; 
        push @sequence, shift;
    } );
    my $root = Path::StepDispatcher::Switch->new();

    my $apple = $root->add(
        Path::StepDispatcher::Switch->new( rule => Path::StepDispatcher::Rule::Regexp->new( regexp => qr/apple\/?/ ), ) );

    $apple->add( Path::StepDispatcher::Item->new( data => 'Apple' ) );

    $ctx->path( "apple" );
    $root->dispatch( $ctx );

    cmp_deeply( \@sequence, [qw/ Apple /] );
}

{
    my $root = path( undef,
        path( qr/apple\/?/,
            item( 'Apple' ), 
            path( qr/banana\/?/, 
                item( 'Apple+Banana' ),
            ),
            interrupt {
                my $ctx = shift;
                $ctx->path( 'grape' ) if $ctx->path;
            },
            path( qr/cherry\/?/, 
                item( 'Apple+Cherry' ),
            ),
            path( qr/grape\/?/, 
                item( 'Apple+Grape' ),
            ),
        ),
    );

    my @sequence;
    my $ctx = Path::StepDispatcher::Context->new( visitor => sub {
        my $self = shift; 
        my $data = shift;
        if ( ref $data eq 'CODE' ) {
            $data->( $self );
        }
        else {
            push @sequence, $data;
        }
    } );
    
    undef @sequence;
    $ctx->path( "apple" );
    $root->dispatch( $ctx );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    undef @sequence;
    $ctx->path( "apple/banana" );
    $root->dispatch( $ctx );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Banana /] );

    undef @sequence;
    $ctx->path( "cherry" );
    $root->dispatch( $ctx );
    cmp_deeply( \@sequence, [] );

    undef @sequence;
    $ctx->path( "apple/cherry" );
    $root->dispatch( $ctx );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Grape /] );
}

