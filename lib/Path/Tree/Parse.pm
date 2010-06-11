package Path::Tree::Parse;

use strict;
use warnings;

use Any::Moose;

use Package::Pkg;

has tree => qw/ is ro required 1 /;

sub parse_node_children {
    my $self = shift;
    my $stream = shift;

    my @children;
    while ( @$stream ) {
        my $argument = shift @$stream;
        die "Invalid argument (undef)" unless defined $argument;
        
        if ( blessed $argument ) {
            push @children, $self->parse_node_children_blessed( $argument, $stream );
        }
        else {
            push @children, $self->parse_node_children_argument( $argument, $stream );
        }
    }
    return @children;
}

sub parse_node_children_blessed {
    my $self = shift;
    my $argument = shift;
    my $stream = shift;

    if ( $argument->isa( 'Path::Tree::Declare::Tag' ) ) {
        return $self->parse_node_children_tagged( $argument, $stream );
    }
    elsif ( $argument->isa( 'Path::Tree::Node' ) ) {
        return $argument;
    }
    elsif ( $argument->isa( 'Path::Tree::Rule' ) ) {
        return $self->parse_node( $argument, $stream );
    }
    elsif ( ref $argument eq 'Regexp' ) {
        return $self->parse_node( $argument, $stream );
    }
    else {
        die "Invalid argument ($argument)";
    }
}

sub parse_node_children_tagged {
    my $self = shift;
    my $argument = shift;
    my $stream = shift;

    my $tag = $argument->tag;
    if      ( $tag eq 'run' )       { return $argument->data }
    elsif   ( $tag eq 'then' )      { return $argument->data }
    else                            { die "Invalid argument ($argument)" }
}

sub parse_node_children_argument {
    my $self = shift;
    my $argument = shift;
    my $stream = shift;

    return $self->parse_node( $argument, $stream );
}

sub parse_node {
    my $self = shift;
    my $rule = shift;
    my $stream = shift;

    my $declare = $self->tree->declare;
    my @rulelist = ( $declare->rule( $rule ) );
    my @node;
    while ( @$stream ) {
        my $argument = shift @$stream;
        if ( ref $argument eq 'ARRAY' ) {
            push @node, $self->parse_node_children( $argument );
            last;
        }
        elsif ( blessed $argument && $argument->isa( 'Path::Tree::Declare::Tag' ) ) {
            my $tag = $argument->tag;
            if      ( $tag eq 'run' )       { push @node, $argument->data }
            elsif   ( $tag eq 'then' )      { push @node, $argument->data }
            elsif   ( $tag eq 'test' )      { push @rulelist, $declare->rule( $argument->data ) }
            else                            { die "Invalid argument ($tag)" }
            last;
        }
        else {
            push @rulelist, $declare->rule( $argument );
        }                              
    }

#    warn "@rulelist @node";
    return $declare->node( @rulelist, @node );
}

1;
