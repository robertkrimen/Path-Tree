package Path::Tree;
# ABSTRACT: Tree-ish path dispatching

use strict;
use warnings;

use Any::Moose;

use Path::Tree::Rule;
use Path::Tree::Node;
use Path::Tree::Dispatch;
use Path::Tree::DataMap;

use Package::Pkg;

has root => qw/ is rw lazy_build 1 /;
sub _build_root {
    my $self = shift;
    return $self->node( $self->declare->always );
}

has _parse_rule => qw/ is ro lazy_build 1 /;
sub _build__parse_rule {
    my $self = shift;
    my $parser = Path::Tree::DataMap->new;
    $parser->rule( type => 'Regexp',
                   sub  { $self->declare->rule( 'Regexp' => regexp => $_ ) } );
    return $parser;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;
    return $self->_parse_rule->map( $input );
}

has declare => qw/ is ro lazy_build 1 /;
sub _build_declare {
    my $self = shift;
    return $self->loader->load( 'Declare' )->new( tree => $self );
}

has loader => qw/ is ro lazy_build 1 /;
sub _build_loader {
    my $self = shift;
    return Package::Pkg->loader( $self->_loader_arguments );
}

sub _loader_arguments {
    my $self = shift;
    my @arguments;
    push @arguments, ref $self;
    push @arguments, 'Path::Tree' unless $arguments[0] eq 'Path::Tree';
    return @arguments;
}

sub dispatch {
    my $self = shift;
    my $path = shift;
    my $dispatch = $self->_build_dispatch( path => $path );
    $self->root->dispatch( $dispatch );
    return $dispatch;
}

sub _build_dispatch {
    my $self = shift;
    my @moniker;
    push @moniker, shift if @_ % 2;
    my $class = $self->loader->load( 'Dispatch', @moniker );
    return $class->new( @_ );
}

sub node {
    my $self = shift;
    return $self->declare->node( @_ );
}

sub _build_node {
    my $self = shift;
    my ( $class, @arguments ) = @_;
    die "Invalid node arguments (@arguments)" if @arguments % 2;
    return $class->new( tree => $self, @arguments );
}

sub build_rule {
    my $self = shift;
    $self->declare->rule( @_ );
}

sub rule {
    my $self = shift;
    return $self->_parse_rule unless @_;
    return $self->build_rule( @_ );
}

sub _build_rule {
    my $self = shift;
    my ( $class, @arguments ) = @_;
    die "Invalid rule arguments (@arguments)" if @arguments % 2;
    return $class->new( @arguments );
}

1;
