namespace DeliveryDisaster.Core
{
    public enum GameState
    {
        Boot,
        MainMenu,
        Playing,
        Paused,
        GameOver
    }

    public enum DeliveryStatus
    {
        Pending,
        AwaitingPickup,
        InTransit,
        Delivered,
        Failed
    }

    public enum PackageCondition
    {
        Pristine,
        Damaged,
        Destroyed
    }

    public enum DisasterSeverity
    {
        Minor,
        Moderate,
        Severe,
        Extreme
    }

    public enum NotificationType
    {
        Info,
        Success,
        Warning,
        Danger
    }
}
