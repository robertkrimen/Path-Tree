package Path::Tree;
# ABSTRACT: Tree-ish path dispatching

use strict;
use warnings;

use Any::Moose;

use Path::Tree::Rule;
use Path::Tree::Node;
use Path::Tree::Dispatch;
use Path::Tree::DataMapper;

use Package::Pkg;

has root => qw/ is rw lazy_build 1 /;
sub _build_root {
    my $self = shift;
    return $self->node( $self->declare->always );
}

has _parse_rule => qw/ is ro lazy_build 1 /;
sub _build__parse_rule {
    my $self = shift;
    my $parser = Path::Tree::DataMapper->new;
    $parser->rule( 'Regexp' => sub { $self->declare->rule( 'Regexp' => regexp => $_ ) } );
    return $parser;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;
    return $self->_parse_rule->map( $input )->result
}

has declare => qw/ is ro lazy_build 1 /;
sub _build_declare {
    my $self = shift;
    require Path::Tree::Declare;
    return Path::Tree::Declare->new( tree => $self );
}

sub rule {
    my $self = shift;
    return $self->_parse_rule unless @_;
    return $self->declare->rule( @_ );
}

sub node {
    my $self = shift;
    return $self->declare->node( @_ );
}

sub dispatch {
    my $self = shift;
    my $path = shift;
    my $dispatch = $self->build_dispatch( path => $path );
    $self->root->dispatch( $dispatch );
    return $dispatch;
}

sub build_dispatch {
    my $self = shift;
    my @moniker;
    push @moniker, shift if @_ % 2;
    return pkg->load_name( $self, 'Dispatch', @moniker )->new( @_ );
}

1;
