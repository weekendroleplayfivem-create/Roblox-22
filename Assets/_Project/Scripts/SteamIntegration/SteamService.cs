namespace DeliveryDisaster.SteamIntegration
{
    /// <summary>
    /// Static access point returning whichever ISteamworksService implementation is
    /// active. Selection happens purely via the SW_STEAMWORKS_NET compilation symbol,
    /// so no runtime branching/reflection is needed and NoOp is always a safe default.
    /// </summary>
    public static class SteamService
    {
        private static ISteamworksService current;

        public static ISteamworksService Current
        {
            get
            {
                if (current == null)
                {
#if SW_STEAMWORKS_NET
                    current = new SteamworksNetService();
#else
                    current = new NoOpSteamworksService();
#endif
                }
                return current;
            }
        }
    }

    /// <summary>
    /// Central registry of achievement/stat API names. These strings MUST exactly
    /// match what you configure in the Steamworks dashboard for this app
    /// (App Admin > Stats & Achievements). See Docs/SteamSetup.md.
    /// </summary>
    public static class SteamIds
    {
        public static class Achievements
        {
            public const string FirstDelivery = "ACH_FIRST_DELIVERY";
            public const string DeliveryStreak10 = "ACH_DELIVERY_STREAK_10";
            public const string DeliveryStreak50 = "ACH_DELIVERY_STREAK_50";
            public const string SurvivedTornado = "ACH_SURVIVED_TORNADO";
            public const string SurvivedFlood = "ACH_SURVIVED_FLOOD";
            public const string DisasterMagnet = "ACH_DISASTER_MAGNET";
            public const string ReachLevel10 = "ACH_REACH_LEVEL_10";
            public const string AllVehiclesUnlocked = "ACH_ALL_VEHICLES_UNLOCKED";
            public const string PerfectRun = "ACH_PERFECT_RUN";
        }

        public static class Stats
        {
            public const string TotalDeliveries = "STAT_TOTAL_DELIVERIES";
            public const string TotalDisastersSurvived = "STAT_TOTAL_DISASTERS_SURVIVED";
            public const string TotalMoneyEarned = "STAT_TOTAL_MONEY_EARNED";
            public const string BestDeliveryStreak = "STAT_BEST_DELIVERY_STREAK";
        }
    }
}
