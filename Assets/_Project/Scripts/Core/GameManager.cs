using UnityEngine;
using DeliveryDisaster.Utils;
using DeliveryDisaster.SaveSystem;

namespace DeliveryDisaster.Core
{
    /// <summary>
    /// Top-level state machine for the game. Does not know the details of any
    /// gameplay subsystem - it only owns the current GameState, timescale, and
    /// broadcasts transitions over the EventBus so UI/audio/gameplay can react.
    /// Place one instance in the bootstrap scene.
    /// </summary>
    public class GameManager : Singleton<GameManager>
    {
        public GameState CurrentState { get; private set; } = GameState.Boot;

        [Header("Run Stats (reset each session)")]
        public int DeliveriesCompletedThisRun;
        public int DeliveriesFailedThisRun;
        public int DisastersSurvivedThisRun;

        [Header("Rules")]
        [Tooltip("Number of failed deliveries in a single run before it's game over.")]
        [SerializeField] private int maxFailuresBeforeGameOver = 3;

        protected override void Awake()
        {
            base.Awake();
            Application.targetFrameRate = 60;
        }

        private void Start()
        {
            SaveManager.Instance.Load();
            SetState(GameState.MainMenu);
        }

        public void SetState(GameState newState)
        {
            if (CurrentState == newState) return;

            CurrentState = newState;
            Time.timeScale = newState == GameState.Paused || newState == GameState.GameOver ? 0f : 1f;
            EventBus.Publish(new GameStateChangedEvent(newState));
        }

        public void StartNewRun()
        {
            DeliveriesCompletedThisRun = 0;
            DeliveriesFailedThisRun = 0;
            DisastersSurvivedThisRun = 0;
            SetState(GameState.Playing);
        }

        public void TogglePause()
        {
            if (CurrentState == GameState.Playing) SetState(GameState.Paused);
            else if (CurrentState == GameState.Paused) SetState(GameState.Playing);
        }

        public void ReportDeliveryCompleted() => DeliveriesCompletedThisRun++;

        public void ReportDeliveryFailed()
        {
            DeliveriesFailedThisRun++;

            if (DeliveriesFailedThisRun >= maxFailuresBeforeGameOver)
            {
                EndRun();
            }
        }

        public void ReportDisasterSurvived() => DisastersSurvivedThisRun++;

        public void EndRun()
        {
            SaveManager.Instance.Save();
            SetState(GameState.GameOver);
        }

        public void QuitToMainMenu()
        {
            SaveManager.Instance.Save();
            SetState(GameState.MainMenu);
        }

        public void QuitApplication()
        {
            SaveManager.Instance.Save();
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit();
#endif
        }
    }
}
