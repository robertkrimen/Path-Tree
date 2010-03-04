use Test::Most;

plan qw/ no_plan /;

use Path::WalkURI::Dispatcher;

ok( 1 );

my ( $dispatcher );

$dispatcher = Path::WalkURI::Dispatcher->new;

$dispatcher->route(

    '/apple' => sub {
        diag "Apple";
    },

    '/*' => [
        '/cherry' => sub {
            diag "Cherry";
        },

        '/*/*' => sub {
            diag "/*/*";
        },
        
        sub {
            diag "/*";
        },

    ],
);

$dispatcher->dispatch( '/apple' );
$dispatcher->dispatch( '/apple/cherry' );
$dispatcher->dispatch( '/banana' );
$dispatcher->dispatch( '/banana/cherry' );
$dispatcher->dispatch( '/banana/0/1/grape' );
