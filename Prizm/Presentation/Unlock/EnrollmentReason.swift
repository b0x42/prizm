/// Reason for showing the biometric enrollment prompt.
/// Determines the copy displayed to the user (design Decision 7).
enum EnrollmentReason: Equatable {
    /// First time the user is offered biometric unlock.
    case firstTime
    /// Biometric enrollment changed — re-offer after invalidation.
    case reEnrollAfterInvalidation
}
