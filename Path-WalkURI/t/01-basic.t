use Test::Most;

plan qw/ no_plan /;

use Path::WalkURI;

ok( 1 );

my ( $wlk );

$wlk = Path::WalkURI->walk( '/apple/0/1/banana' );
ok( $wlk->consume( '/apple' ) );
is( $wlk->leftover, '/0/1/banana' );
is( $wlk->step->segment, '/apple' );

ok( $wlk->consume( '/*/*' ) );
cmp_deeply( $wlk->step->captured, [qw/ 0 1 /] );
is( $wlk->leftover, '/banana' );
is( $wlk->step->prefix, '/apple' );
is( $wlk->step->segment, '/0/1' );

ok( $wlk->consume( '/*' ) );
cmp_deeply( $wlk->step->captured, [qw/ banana /] );
is( $wlk->leftover, '' );

$wlk = Path::WalkURI->walk( '/apple/0/1/banana' );
ok( $wlk->consume( 1 ) );
is( $wlk->leftover, '/0/1/banana' );

ok( $wlk->consume( 2 ) );
cmp_deeply( $wlk->step->captured, [qw/ 0 1 /] );
is( $wlk->leftover, '/banana' );

ok( $wlk->consume( 1 ) );
cmp_deeply( $wlk->step->captured, [qw{ banana }] );
is( $wlk->leftover, '' );

