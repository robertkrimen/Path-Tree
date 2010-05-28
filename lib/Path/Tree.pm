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
    $parser->rule( type => 'ARRAY',
                   sub  { $self->declare->rule( 'RegexpToken' => tokenlist => $_ ) } );
    return $parser;
}

sub parse_rule {
    my $self = shift;
    my $input = shift;
    return $self->_parse_rule->map( $input );
}

has parse => qw/ is ro lazy_build 1 /;
sub _build_parse {
    my $self = shift;
    return $self->loader->load( 'Parse' )->new( tree => $self );
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

has dispatch_class => qw/ is rw isa Str lazy_build 1 /;
sub _build_dispatch_class { $_[0]->loader->load( 'Dispatch' ) }

has dispatch_step_class => qw/ is rw isa Str lazy_build 1  /;
sub _build_dispatch_step_class { $_[0]->loader->load( 'DispatchStep' ) }

sub _build_dispatch {
    my $self = shift;
    my $class = $self->dispatch_class;
    return $class->new( tree => $self, @_ );
}

sub _build_dispatch_step {
    my $self = shift;
    my $class = $self->dispatch_step_class;
    return $class->new( @_ );
}

has node_class => qw/ is rw isa Str lazy_build 1 /;
sub _build_node_class { $_[0]->loader->load( 'Node' ) }

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
