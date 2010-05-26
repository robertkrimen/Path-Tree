package Path::Tree::Dispatch;

use Any::Moose;

use Try::Tiny;

has tree => qw/ is ro required 1 /;
has path => qw/ is rw required 1 isa Str /;

has _trail => qw/ is ro isa ArrayRef /, default => sub { [] };
sub trail {
    my $self = shift;
    return @{ $self->_trail } unless @_;
    my $ii = shift;
    $ii = -1 unless defined $ii;
    return $self->_trail->[ $ii ];
}

sub head {
    my $self = shift;
    return $self->_trail->[ 0 ];
}

sub tail {
    my $self = shift;
    return $self->_trail->[ -1 ];
}

sub consume {
    my $self = shift;
    my $node = shift;

    my ( $path, $step, $lstep, $lprefix, $lsegment );
    if ( $lstep = $self->tail ) {
        $path = $lstep->leftover;
        $lprefix = $lstep->prefix;
        $lsegment = $lstep->segment;
    }
    else {
        $path = $self->path;
        $lprefix = $lsegment = '';
    }
    
    return 0 unless my $match = $node->match( $path );

    {
        my $leftover = $match->{leftover};
        my $segment = substr $path, 0, -1 * length $leftover;
        my $prefix = join '', $lprefix, $lsegment;

        $step = $self->push_step(
            match => $match,
            segment => $segment,
            prefix => $prefix,
            leftover => $leftover,
            node => $node,
        );
    }

    return 1;
}

sub push_step {
    my $self = shift;
    my $step = $self->tree->_build_dispatch_step( @_ );
    push @{ $self->_trail }, $step;
    return $step;
}

sub pop_step {
    my $self = shift;
    pop @{ $self->_trail };
    # TODO Cannot pop off the last (first) one
}

sub visit {
    my $self = shift;
    my $data = shift;

    if ( ref $data eq 'CODE' ) {
        return $data->( $self );
    }
    else {
        die "Do not know how to visit data (", defined $data ? $data : 'undef', ")";
    }
}

package Path::Tree::DispatchStep;

use Any::Moose;

has node => qw/ is ro required 1 /;
has [qw/ prefix leftover segment /] => qw/ is ro isa Str /, default => '';
has captured => qw/ is ro isa ArrayRef /, default => sub { [] };

1;

__END__

has dispatcher => qw/ is ro required 1 /;

has path => qw/ accessor initial_path required 1 isa Str /;

has trail => qw/ is ro isa ArrayRef /, default => sub { [] };

has visitor => qw/ is rw isa CodeRef /;

sub BUILD {
    my $self = shift;
    $self->push( route => $self->root, leftover => $self->initial_path );
}

sub walk {
    my $self = shift;
    $self->walk_route( $self->root );
}

sub walk_route {
    my $self = shift;
    my $route = shift;

    $self->visit( $route->before ) if $route->before;

    for my $child ( $route->children ) {
        if ( blessed $child && $child->isa(qw/ Path::Tree::Route /) ) {
            # TODO && $child->does( 'Route' )
            last if $self->visit_route( $child );
        }
        else {
            $self->visit( $child );
        }
    }

    $self->visit( $route->after ) if $route->after;

    $self->visit( $route->end ) if $route->end;
}

sub visit {
    my $self = shift;
    my $data = shift;

    $self->dispatcher->visit( $self->visitor, walker => $self, data => $data );
}

sub visit_route {
    my $self = shift;
    my $route = shift;

    return 0 unless $self->consume( $route ); # Does a push

    my $error;
    try { $self->walk_route( $route ) } catch { $error = $_ };
    $self->pop;
    die $error if $error;

    return 1;
}
