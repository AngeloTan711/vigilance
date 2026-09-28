<?php

namespace App\Exceptions;

use Exception;

/// Thrown by AlertStateMachine whenever the requested transition doesn't
/// match the alert's current status. Caught in AlertController::handleTransition
/// (NOT in bootstrap/app.php's exception handling — that callback is
/// deliberately left empty for this exception type, see its comment) and
/// converted to a 409 Conflict with the current status in the body, per
/// docs/ARCHITECTURE.md §1.4 / §5: "include the current status so the
/// client can resynchronize."
class InvalidAlertTransitionException extends Exception
{
    public function __construct(public readonly string $currentStatus, string $message)
    {
        parent::__construct($message);
    }
}
