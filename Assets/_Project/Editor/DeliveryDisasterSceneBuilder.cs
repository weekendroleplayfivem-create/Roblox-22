using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.Events;
using DeliveryDisaster.Core;
using DeliveryDisaster.SaveSystem;
using DeliveryDisaster.Economy;
using DeliveryDisaster.Vehicles;
using DeliveryDisaster.Player;
using DeliveryDisaster.Delivery;
using DeliveryDisaster.Disasters;
using DeliveryDisaster.Disasters.Types;
using DeliveryDisaster.World;
using DeliveryDisaster.UI;
using DeliveryDisaster.Audio;
using DeliveryDisaster.SteamIntegration;
using Object = UnityEngine.Object;

namespace DeliveryDisaster.EditorTools
{
    /// <summary>
    /// Programmatically builds MainMenu.unity and Gameplay.unity (plus the
    /// supporting prefabs/ScriptableObjects they need) using real Unity Editor
    /// APIs. This exists because scene/prefab files are fragile to hand-author
    /// as raw YAML outside the Editor - building them through AddComponent/
    /// SerializedObject instead guarantees every reference resolves correctly.
    ///
    /// Usage: open this project in Unity, then
    /// "Delivery Disaster > Build Everything (Content + Scenes)".
    /// Safe to re-run - existing prefabs/ScriptableObjects are reused rather
    /// than duplicated, and it asks before overwriting existing scenes.
    /// </summary>
    public static class DeliveryDisasterSceneBuilder
    {
        private const string ScenesFolder = "Assets/_Project/Scenes";
        private const string PrefabsFolder = "Assets/_Project/Prefabs";
        private const string VehiclesSoFolder = "Assets/_Project/ScriptableObjects/Vehicles";
        private const string DisastersSoFolder = "Assets/_Project/ScriptableObjects/Disasters";
        private const string AudioFolder = "Assets/_Project/Audio";

        private const string MainMenuScenePath = ScenesFolder + "/MainMenu.unity";
        private const string GameplayScenePath = ScenesFolder + "/Gameplay.unity";

        private class ContentRefs
        {
            public VehicleData StarterVehicle;
            public GameObject VehiclePrefab;
            public SfxLibrary Sfx;
            public GameObject NpcPrefab;
            public GameObject ToastPrefab;
            public List<DisasterDefinition> DisasterDefinitions = new List<DisasterDefinition>();
        }

        private class DisasterSpec
        {
            public string Id;
            public string DisplayName;
            public System.Type ComponentType;
            public float Warning, Duration, Cooldown, MinDifficulty;
            public string Category = "";
        }

        private static readonly DisasterSpec[] DisasterSpecs =
        {
            new DisasterSpec { Id = "tornado", DisplayName = "Tornado", ComponentType = typeof(TornadoDisaster), Warning = 4, Duration = 14, Cooldown = 30, MinDifficulty = 1.5f },
            new DisasterSpec { Id = "flood", DisplayName = "Flood", ComponentType = typeof(FloodDisaster), Warning = 5, Duration = 16, Cooldown = 35, MinDifficulty = 1.5f },
            new DisasterSpec { Id = "falling_objects", DisplayName = "Falling Objects", ComponentType = typeof(FallingObjectsDisaster), Warning = 3, Duration = 12, Cooldown = 25, MinDifficulty = 1.0f },
            new DisasterSpec { Id = "road_collapse", DisplayName = "Road Collapse", ComponentType = typeof(RoadCollapseDisaster), Warning = 3, Duration = 20, Cooldown = 30, MinDifficulty = 1.0f },
            new DisasterSpec { Id = "vehicle_explosion", DisplayName = "Vehicle Explosion", ComponentType = typeof(VehicleExplosionDisaster), Warning = 2, Duration = 6, Cooldown = 25, MinDifficulty = 2.0f },
            new DisasterSpec { Id = "traffic_accident", DisplayName = "Traffic Accident", ComponentType = typeof(TrafficAccidentDisaster), Warning = 3, Duration = 15, Cooldown = 25, MinDifficulty = 1.0f },
            new DisasterSpec { Id = "construction_zone", DisplayName = "Construction Zone", ComponentType = typeof(ConstructionZoneDisaster), Warning = 3, Duration = 18, Cooldown = 30, MinDifficulty = 1.0f },
            new DisasterSpec { Id = "bridge_blocked", DisplayName = "Bridge Blocked", ComponentType = typeof(BridgeBlockedDisaster), Warning = 3, Duration = 20, Cooldown = 40, MinDifficulty = 2.5f, Category = "Bridge" },
        };

        // ------------------------------------------------------------------
        // Menu entry points
        // ------------------------------------------------------------------

        [MenuItem("Delivery Disaster/Build Everything (Content + Scenes)")]
        public static void BuildEverything()
        {
            var content = EnsureContent();
            BuildScenesInternal(content);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[SceneBuilder] Done. Open Assets/_Project/Scenes/MainMenu.unity and press Play.");
        }

        [MenuItem("Delivery Disaster/1. Build Content Only (Prefabs + ScriptableObjects)")]
        public static void BuildContentOnly()
        {
            EnsureContent();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[SceneBuilder] Content built under Assets/_Project/Prefabs, ScriptableObjects, Audio.");
        }

        [MenuItem("Delivery Disaster/2. Build Scenes Only (MainMenu + Gameplay)")]
        public static void BuildScenesOnly()
        {
            var content = EnsureContent();
            BuildScenesInternal(content);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[SceneBuilder] Scenes built.");
        }

        private static void BuildScenesInternal(ContentRefs content)
        {
            if ((File.Exists(MainMenuScenePath) || File.Exists(GameplayScenePath)) &&
                !EditorUtility.DisplayDialog(
                    "Delivery Disaster - Build Scenes",
                    "MainMenu.unity and/or Gameplay.unity already exist and will be completely overwritten. Continue?",
                    "Overwrite", "Cancel"))
            {
                return;
            }

            BuildMainMenuScene(content);
            BuildGameplayScene(content);
            ConfigureBuildSettings();
        }

        // ------------------------------------------------------------------
        // Content (prefabs + ScriptableObjects)
        // ------------------------------------------------------------------

        private static ContentRefs EnsureContent()
        {
            EnsureFolder(VehiclesSoFolder);
            EnsureFolder(DisastersSoFolder);
            EnsureFolder(PrefabsFolder);
            EnsureFolder(AudioFolder);

            var refs = new ContentRefs();

            string vehicleDataPath = VehiclesSoFolder + "/Vehicle_Starter.asset";
            var vehicleData = AssetDatabase.LoadAssetAtPath<VehicleData>(vehicleDataPath);
            if (vehicleData == null)
            {
                vehicleData = ScriptableObject.CreateInstance<VehicleData>();
                AssetDatabase.CreateAsset(vehicleData, vehicleDataPath);
            }
            SetStringField(vehicleData, "id", "starter_van");
            SetStringField(vehicleData, "displayName", "Starter Van");
            SetBoolField(vehicleData, "isStarterVehicle", true);

            refs.Sfx = GetOrCreateScriptableObject<SfxLibrary>(AudioFolder + "/SfxLibrary.asset");

            refs.VehiclePrefab = GetOrCreateVehiclePrefab(PrefabsFolder + "/Vehicle_Starter.prefab", vehicleData, refs.Sfx);
            SetObjectField(vehicleData, "vehiclePrefab", refs.VehiclePrefab);
            refs.StarterVehicle = vehicleData;

            refs.NpcPrefab = GetOrCreateNpcPrefab(PrefabsFolder + "/NPC_Vehicle.prefab");
            refs.ToastPrefab = GetOrCreateToastPrefab(PrefabsFolder + "/Toast.prefab");

            foreach (var spec in DisasterSpecs)
            {
                string safeName = spec.DisplayName.Replace(" ", "");

                string prefabPath = $"{PrefabsFolder}/Disaster_{safeName}.prefab";
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
                if (prefab == null)
                {
                    var go = new GameObject(safeName);
                    go.AddComponent(spec.ComponentType);
                    prefab = PrefabUtility.SaveAsPrefabAsset(go, prefabPath);
                    Object.DestroyImmediate(go);
                }

                string defPath = $"{DisastersSoFolder}/Disaster_{safeName}.asset";
                var def = AssetDatabase.LoadAssetAtPath<DisasterDefinition>(defPath);
                if (def == null)
                {
                    def = ScriptableObject.CreateInstance<DisasterDefinition>();
                    AssetDatabase.CreateAsset(def, defPath);
                }

                SetStringField(def, "disasterId", spec.Id);
                SetStringField(def, "displayName", spec.DisplayName);
                SetObjectField(def, "disasterPrefab", prefab);
                SetFloatField(def, "warningDuration", spec.Warning);
                SetFloatField(def, "activeDuration", spec.Duration);
                SetFloatField(def, "cooldownSeconds", spec.Cooldown);
                SetFloatField(def, "minDifficulty", spec.MinDifficulty);
                SetStringField(def, "requiredSpawnCategory", spec.Category);

                refs.DisasterDefinitions.Add(def);
            }

            return refs;
        }

        private static GameObject GetOrCreateVehiclePrefab(string path, VehicleData vehicleData, SfxLibrary sfx)
        {
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (existing != null) return existing;

            var root = GameObject.CreatePrimitive(PrimitiveType.Cube);
            root.name = "Vehicle_Starter";
            root.transform.localScale = new Vector3(2f, 1f, 4f);

            var rb = root.GetComponent<Rigidbody>();
            if (rb == null) rb = root.AddComponent<Rigidbody>();
            rb.mass = 1200f;
            rb.drag = 0.05f;
            rb.angularDrag = 0.5f;

            Vector3[] wheelPositions =
            {
                new Vector3(-0.9f, -0.3f, 1.3f),
                new Vector3(0.9f, -0.3f, 1.3f),
                new Vector3(-0.9f, -0.3f, -1.3f),
                new Vector3(0.9f, -0.3f, -1.3f),
            };
            string[] wheelNames = { "WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight" };
            var wheels = new WheelCollider[4];

            for (int i = 0; i < 4; i++)
            {
                var wheelGO = new GameObject(wheelNames[i]);
                wheelGO.transform.SetParent(root.transform, false);
                wheelGO.transform.localPosition = wheelPositions[i];
                var wc = wheelGO.AddComponent<WheelCollider>();
                wc.radius = 0.4f;
                wc.suspensionDistance = 0.3f;
                wheels[i] = wc;
            }

            var controller = root.AddComponent<VehicleController>();
            SetObjectField(controller, "frontLeft", wheels[0]);
            SetObjectField(controller, "frontRight", wheels[1]);
            SetObjectField(controller, "rearLeft", wheels[2]);
            SetObjectField(controller, "rearRight", wheels[3]);
            SetObjectField(controller, "vehicleData", vehicleData);

            var damage = root.AddComponent<VehicleDamageSystem>();
            SetObjectField(damage, "vehicleData", vehicleData);

            root.AddComponent<PackageController>();

            var interactionGO = new GameObject("InteractionRange");
            interactionGO.transform.SetParent(root.transform, false);
            var trigger = interactionGO.AddComponent<SphereCollider>();
            trigger.isTrigger = true;
            trigger.radius = 6f;
            root.AddComponent<PlayerInteraction>();

            var audioSource = root.AddComponent<AudioSource>();
            audioSource.playOnAwake = false;
            var vehicleAudio = root.AddComponent<VehicleAudio>();
            SetObjectField(vehicleAudio, "library", sfx);

            var saved = PrefabUtility.SaveAsPrefabAsset(root, path);
            Object.DestroyImmediate(root);
            return saved;
        }

        private static GameObject GetOrCreateNpcPrefab(string path)
        {
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (existing != null) return existing;

            var npc = GameObject.CreatePrimitive(PrimitiveType.Cube);
            npc.name = "NPC_Vehicle";
            npc.transform.localScale = new Vector3(1.8f, 1f, 3.6f);

            var rb = npc.AddComponent<Rigidbody>();
            rb.mass = 1000f;
            rb.constraints = RigidbodyConstraints.FreezeRotationX | RigidbodyConstraints.FreezeRotationZ;

            var ai = npc.AddComponent<NPCVehicleAI>();
            SetIntField(ai, "obstacleLayers", 1 << 0); // Default layer - matches every primitive this builder creates

            npc.AddComponent<Obstacle>();

            var saved = PrefabUtility.SaveAsPrefabAsset(npc, path);
            Object.DestroyImmediate(npc);
            return saved;
        }

        private static GameObject GetOrCreateToastPrefab(string path)
        {
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (existing != null) return existing;

            var toast = new GameObject("Toast", typeof(RectTransform), typeof(Image));
            var toastRect = toast.GetComponent<RectTransform>();
            toastRect.sizeDelta = new Vector2(400, 60);
            toast.GetComponent<Image>().color = new Color(0f, 0f, 0f, 0.75f);

            var textGO = new GameObject("Text", typeof(RectTransform), typeof(TextMeshProUGUI));
            textGO.transform.SetParent(toast.transform, false);
            StretchFull(textGO.GetComponent<RectTransform>());
            var tmp = textGO.GetComponent<TextMeshProUGUI>();
            tmp.fontSize = 22;
            tmp.alignment = TextAlignmentOptions.Center;
            tmp.color = Color.white;

            var saved = PrefabUtility.SaveAsPrefabAsset(toast, path);
            Object.DestroyImmediate(toast);
            return saved;
        }

        private static T GetOrCreateScriptableObject<T>(string path) where T : ScriptableObject
        {
            var existing = AssetDatabase.LoadAssetAtPath<T>(path);
            if (existing != null) return existing;

            var instance = ScriptableObject.CreateInstance<T>();
            AssetDatabase.CreateAsset(instance, path);
            return instance;
        }

        // ------------------------------------------------------------------
        // MainMenu.unity
        // ------------------------------------------------------------------

        private static void BuildMainMenuScene(ContentRefs content)
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var bootstrap = new GameObject("_Bootstrap");
            bootstrap.AddComponent<GameManager>();
            bootstrap.AddComponent<SaveManager>();
            bootstrap.AddComponent<SteamBootstrap>();
            bootstrap.AddComponent<SteamAchievementTracker>();

            var audioManager = bootstrap.AddComponent<AudioManager>();
            SetObjectField(audioManager, "library", content.Sfx);

            var unlockManager = bootstrap.AddComponent<UnlockManager>();
            SetObjectArrayField(unlockManager, "allVehicles", new Object[] { content.StarterVehicle });

            bootstrap.AddComponent<ProgressionManager>();
            bootstrap.AddComponent<EconomyManager>();

            var camGO = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener));
            camGO.tag = "MainCamera";
            camGO.transform.position = new Vector3(0f, 2f, -6f);
            camGO.transform.rotation = Quaternion.Euler(10f, 0f, 0f);

            var lightGO = new GameObject("Directional Light", typeof(Light));
            var light = lightGO.GetComponent<Light>();
            light.type = LightType.Directional;
            lightGO.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            var canvasGO = CreateCanvas("Canvas");
            CreateEventSystem();

            var mainMenuPanel = CreatePanel("MainMenuPanel", canvasGO.transform, new Color(0.05f, 0.05f, 0.08f, 0.95f));
            var mainMenuUI = mainMenuPanel.AddComponent<MainMenuUI>();
            SetObjectField(mainMenuUI, "panelRoot", mainMenuPanel);

            CreateLabel("Title", mainMenuPanel.transform, "DELIVERY DISASTER", 56, new Vector2(0, 220), new Vector2(900, 100));

            var playBtn = CreateButton("PlayButton", mainMenuPanel.transform, "Play", new Vector2(0, 40));
            var settingsBtn = CreateButton("SettingsButton", mainMenuPanel.transform, "Settings", new Vector2(0, -40));
            var quitBtn = CreateButton("QuitButton", mainMenuPanel.transform, "Quit", new Vector2(0, -120));

            var settingsPanel = BuildSettingsPanel(canvasGO.transform);
            settingsPanel.SetActive(false);
            var settingsMenuUI = settingsPanel.GetComponent<SettingsMenuUI>();
            SetObjectField(mainMenuUI, "settingsMenu", settingsMenuUI);

            UnityEventTools.AddPersistentListener(playBtn.onClick, mainMenuUI.OnPlayClicked);
            UnityEventTools.AddPersistentListener(settingsBtn.onClick, mainMenuUI.OnSettingsClicked);
            UnityEventTools.AddPersistentListener(quitBtn.onClick, mainMenuUI.OnQuitClicked);

            EnsureFolder(ScenesFolder);
            EditorSceneManager.SaveScene(scene, MainMenuScenePath);
        }

        // ------------------------------------------------------------------
        // Gameplay.unity
        // ------------------------------------------------------------------

        private static void BuildGameplayScene(ContentRefs content)
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            ground.transform.localScale = new Vector3(20f, 1f, 20f);

            var playerSpawnGO = new GameObject("PlayerSpawn");
            playerSpawnGO.transform.position = new Vector3(0f, 0.5f, 0f);
            var playerSpawn = playerSpawnGO.AddComponent<SpawnPoint>();
            SetEnumIndexField(playerSpawn, "type", (int)SpawnPointType.PlayerStart);

            var camGO = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener));
            camGO.tag = "MainCamera";
            var camFollow = camGO.AddComponent<VehicleCameraFollow>();

            var lightGO = new GameObject("Directional Light", typeof(Light));
            lightGO.GetComponent<Light>().type = LightType.Directional;
            lightGO.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            var spawnerGO = new GameObject("VehicleSpawner");
            var vehicleSpawner = spawnerGO.AddComponent<VehicleSpawner>();
            SetObjectField(vehicleSpawner, "followCamera", camFollow);

            const int locationCount = 6;
            const float locationRadius = 60f;
            string[] locationNames = { "Pizza Place", "Office Tower", "Warehouse District", "Riverside Homes", "Central Mall", "Hillside Cabins" };
            for (int i = 0; i < locationCount; i++)
            {
                float angle = i * Mathf.PI * 2f / locationCount;
                Vector3 pos = new Vector3(Mathf.Cos(angle) * locationRadius, 0.5f, Mathf.Sin(angle) * locationRadius);
                var go = new GameObject("DeliveryLocation_" + locationNames[i].Replace(" ", ""));
                go.transform.position = pos;
                var col = go.AddComponent<SphereCollider>();
                col.isTrigger = true;
                col.radius = 5f;
                var loc = go.AddComponent<DeliveryLocation>();
                SetStringField(loc, "locationName", locationNames[i]);
            }

            const int waypointCount = 8;
            const float waypointRadius = 80f;
            var waypoints = new List<Waypoint>();
            for (int i = 0; i < waypointCount; i++)
            {
                float angle = i * Mathf.PI * 2f / waypointCount;
                Vector3 pos = new Vector3(Mathf.Cos(angle) * waypointRadius, 0.2f, Mathf.Sin(angle) * waypointRadius);
                var go = new GameObject($"Waypoint_{i}");
                go.transform.position = pos;
                waypoints.Add(go.AddComponent<Waypoint>());
            }
            for (int i = 0; i < waypointCount; i++)
            {
                var next = waypoints[(i + 1) % waypointCount];
                SetObjectArrayField(waypoints[i], "next", new Object[] { next });
            }

            var trafficSpawnMarker = waypoints[0].gameObject.AddComponent<SpawnPoint>();
            SetEnumIndexField(trafficSpawnMarker, "type", (int)SpawnPointType.TrafficSpawn);

            for (int i = 0; i < waypointCount; i += 2)
            {
                var cpGO = new GameObject($"Checkpoint_{i}");
                cpGO.transform.position = waypoints[i].transform.position;
                var col = cpGO.AddComponent<SphereCollider>();
                col.isTrigger = true;
                col.radius = 8f;
                cpGO.AddComponent<Checkpoint>();
            }

            var bridgeGO = new GameObject("DisasterSpawnPoint_Bridge");
            bridgeGO.transform.position = new Vector3(locationRadius * 0.5f, 0.5f, 0f);
            var bridgeSpawn = bridgeGO.AddComponent<DisasterSpawnPoint>();
            SetStringField(bridgeSpawn, "category", "Bridge");

            var trafficSpawnerGO = new GameObject("TrafficSpawner");
            var trafficSpawner = trafficSpawnerGO.AddComponent<TrafficSpawner>();
            SetObjectField(trafficSpawner, "npcVehiclePrefab", content.NpcPrefab);
            SetObjectArrayField(trafficSpawner, "fallbackWaypoints", waypoints.Select(w => (Object)w).ToArray());

            new GameObject("DeliveryManager").AddComponent<DeliveryManager>();
            new GameObject("DifficultyManager").AddComponent<DifficultyManager>();

            var disasterManagerGO = new GameObject("DisasterManager");
            var disasterManager = disasterManagerGO.AddComponent<DisasterManager>();
            SetObjectArrayField(disasterManager, "disasterPool", content.DisasterDefinitions.Select(d => (Object)d).ToArray());

            new GameObject("PauseInputListener").AddComponent<PauseInputListener>();

            BuildHudCanvas(content);

            EnsureFolder(ScenesFolder);
            EditorSceneManager.SaveScene(scene, GameplayScenePath);
        }

        private static void BuildHudCanvas(ContentRefs content)
        {
            var canvasGO = CreateCanvas("HUD Canvas");
            CreateEventSystem();

            var hudRoot = CreatePanel("HUD", canvasGO.transform, new Color(0f, 0f, 0f, 0f));
            var hudController = canvasGO.AddComponent<HUDController>();
            SetObjectField(hudController, "hudRoot", hudRoot);

            var deliveryPanelGO = CreatePanel("DeliveryPanel", hudRoot.transform, new Color(0f, 0f, 0f, 0.55f));
            AnchorTopLeft(deliveryPanelGO.GetComponent<RectTransform>(), new Vector2(340, 110), new Vector2(20, -20));
            var deliveryPanelUI = deliveryPanelGO.AddComponent<DeliveryPanelUI>();
            var titleLbl = CreateLabel("TitleText", deliveryPanelGO.transform, "", 16, new Vector2(0, 35), new Vector2(320, 25));
            var targetLbl = CreateLabel("TargetText", deliveryPanelGO.transform, "", 20, new Vector2(0, 0), new Vector2(320, 30));
            var rewardLbl = CreateLabel("RewardText", deliveryPanelGO.transform, "", 16, new Vector2(0, -35), new Vector2(320, 25));
            SetObjectField(deliveryPanelUI, "panelRoot", deliveryPanelGO);
            SetObjectField(deliveryPanelUI, "titleText", titleLbl);
            SetObjectField(deliveryPanelUI, "targetLocationText", targetLbl);
            SetObjectField(deliveryPanelUI, "rewardText", rewardLbl);
            deliveryPanelGO.SetActive(false);

            var timerGO = CreatePanel("TimerPanel", hudRoot.transform, new Color(0f, 0f, 0f, 0.4f));
            AnchorTopCenter(timerGO.GetComponent<RectTransform>(), new Vector2(200, 60), new Vector2(0, -20));
            var timerText = CreateLabel("TimerText", timerGO.transform, "00:00", 30, Vector2.zero, new Vector2(180, 50));
            var timerUI = timerGO.AddComponent<TimerUI>();
            SetObjectField(timerUI, "timeText", timerText);

            var moneyXpGO = CreatePanel("MoneyXpPanel", hudRoot.transform, new Color(0f, 0f, 0f, 0.4f));
            AnchorTopRight(moneyXpGO.GetComponent<RectTransform>(), new Vector2(240, 80), new Vector2(-20, -20));
            var moneyLbl = CreateLabel("MoneyText", moneyXpGO.transform, "$0", 22, new Vector2(0, 15), new Vector2(200, 30));
            var levelLbl = CreateLabel("LevelText", moneyXpGO.transform, "Lv 1", 18, new Vector2(0, -15), new Vector2(200, 30));
            var moneyXpUI = moneyXpGO.AddComponent<MoneyXpUI>();
            SetObjectField(moneyXpUI, "moneyText", moneyLbl);
            SetObjectField(moneyXpUI, "levelText", levelLbl);

            var packageStatusGO = CreatePanel("PackageStatusPanel", hudRoot.transform, new Color(0f, 0f, 0f, 0.4f));
            AnchorTopLeft(packageStatusGO.GetComponent<RectTransform>(), new Vector2(340, 40), new Vector2(20, -140));
            var packageLbl = CreateLabel("StatusText", packageStatusGO.transform, "", 16, Vector2.zero, new Vector2(320, 30));
            var packageStatusUI = packageStatusGO.AddComponent<PackageStatusUI>();
            SetObjectField(packageStatusUI, "root", packageStatusGO);
            SetObjectField(packageStatusUI, "statusText", packageLbl);
            packageStatusGO.SetActive(false);

            var warningGO = CreatePanel("DisasterWarningBanner", hudRoot.transform, new Color(0.6f, 0.05f, 0.05f, 0.85f));
            AnchorTopCenter(warningGO.GetComponent<RectTransform>(), new Vector2(640, 70), new Vector2(0, -100));
            var warningLbl = CreateLabel("WarningText", warningGO.transform, "", 28, Vector2.zero, new Vector2(600, 60));
            var warningCanvasGroup = warningGO.AddComponent<CanvasGroup>();
            var disasterWarningUI = warningGO.AddComponent<DisasterWarningUI>();
            SetObjectField(disasterWarningUI, "bannerRoot", warningGO);
            SetObjectField(disasterWarningUI, "warningText", warningLbl);
            SetObjectField(disasterWarningUI, "canvasGroup", warningCanvasGroup);
            warningGO.SetActive(false);

            var notifGO = new GameObject("NotificationContainer", typeof(RectTransform));
            notifGO.transform.SetParent(hudRoot.transform, false);
            var notifRect = notifGO.GetComponent<RectTransform>();
            notifRect.anchorMin = new Vector2(1f, 0.5f);
            notifRect.anchorMax = new Vector2(1f, 0.5f);
            notifRect.pivot = new Vector2(1f, 0.5f);
            notifRect.sizeDelta = new Vector2(360, 400);
            notifRect.anchoredPosition = new Vector2(-20, 0);
            var vlg = notifGO.AddComponent<VerticalLayoutGroup>();
            vlg.childForceExpandHeight = false;
            vlg.spacing = 8f;
            vlg.childAlignment = TextAnchor.LowerRight;
            var notificationSystem = notifGO.AddComponent<NotificationSystem>();
            SetObjectField(notificationSystem, "container", notifRect);
            SetObjectField(notificationSystem, "toastPrefab", content.ToastPrefab);

            var pausePanel = CreatePanel("PauseMenuPanel", canvasGO.transform, new Color(0.05f, 0.05f, 0.08f, 0.95f));
            var pauseMenuUI = pausePanel.AddComponent<PauseMenuUI>();
            SetObjectField(pauseMenuUI, "panelRoot", pausePanel);
            CreateLabel("Title", pausePanel.transform, "PAUSED", 40, new Vector2(0, 220), new Vector2(400, 60));
            var resumeBtn = CreateButton("ResumeButton", pausePanel.transform, "Resume", new Vector2(0, 100));
            var pauseSettingsBtn = CreateButton("SettingsButton", pausePanel.transform, "Settings", new Vector2(0, 30));
            var quitMenuBtn = CreateButton("QuitToMenuButton", pausePanel.transform, "Quit to Menu", new Vector2(0, -40));
            var quitAppBtn = CreateButton("QuitAppButton", pausePanel.transform, "Quit Game", new Vector2(0, -110));
            pausePanel.SetActive(false);

            var settingsPanel = BuildSettingsPanel(canvasGO.transform);
            settingsPanel.SetActive(false);
            var settingsMenuUI = settingsPanel.GetComponent<SettingsMenuUI>();
            SetObjectField(pauseMenuUI, "settingsMenu", settingsMenuUI);

            UnityEventTools.AddPersistentListener(resumeBtn.onClick, pauseMenuUI.OnResumeClicked);
            UnityEventTools.AddPersistentListener(pauseSettingsBtn.onClick, pauseMenuUI.OnSettingsClicked);
            UnityEventTools.AddPersistentListener(quitMenuBtn.onClick, pauseMenuUI.OnQuitToMenuClicked);
            UnityEventTools.AddPersistentListener(quitAppBtn.onClick, pauseMenuUI.OnQuitApplicationClicked);

            var gameOverPanel = CreatePanel("GameOverPanel", canvasGO.transform, new Color(0.1f, 0.02f, 0.02f, 0.95f));
            var gameOverUI = gameOverPanel.AddComponent<GameOverUI>();
            SetObjectField(gameOverUI, "panelRoot", gameOverPanel);
            CreateLabel("Title", gameOverPanel.transform, "GAME OVER", 46, new Vector2(0, 200), new Vector2(500, 60));
            var summaryLbl = CreateLabel("SummaryText", gameOverPanel.transform, "", 20, new Vector2(0, 80), new Vector2(500, 150));
            SetObjectField(gameOverUI, "summaryText", summaryLbl);
            var retryBtn = CreateButton("RetryButton", gameOverPanel.transform, "Retry", new Vector2(0, -60));
            var gameOverMenuBtn = CreateButton("MainMenuButton", gameOverPanel.transform, "Main Menu", new Vector2(0, -140));
            UnityEventTools.AddPersistentListener(retryBtn.onClick, gameOverUI.OnRetryClicked);
            UnityEventTools.AddPersistentListener(gameOverMenuBtn.onClick, gameOverUI.OnMainMenuClicked);
            gameOverPanel.SetActive(false);
        }

        private static GameObject BuildSettingsPanel(Transform canvasParent)
        {
            var panel = CreatePanel("SettingsPanel", canvasParent, new Color(0.05f, 0.05f, 0.08f, 0.97f));
            var settingsUI = panel.AddComponent<SettingsMenuUI>();
            SetObjectField(settingsUI, "panelRoot", panel);

            CreateLabel("Title", panel.transform, "SETTINGS", 38, new Vector2(0, 300), new Vector2(600, 60));

            var masterSlider = CreateSlider("MasterVolumeSlider", panel.transform, new Vector2(60, 200));
            var musicSlider = CreateSlider("MusicVolumeSlider", panel.transform, new Vector2(60, 140));
            var sfxSlider = CreateSlider("SfxVolumeSlider", panel.transform, new Vector2(60, 80));

            CreateLabel("MasterLabel", panel.transform, "Master Volume", 16, new Vector2(-160, 200), new Vector2(200, 30));
            CreateLabel("MusicLabel", panel.transform, "Music Volume", 16, new Vector2(-160, 140), new Vector2(200, 30));
            CreateLabel("SfxLabel", panel.transform, "SFX Volume", 16, new Vector2(-160, 80), new Vector2(200, 30));

            var invertToggle = CreateToggle("InvertYToggle", panel.transform, "Invert Y Look", new Vector2(-150, 10));
            var shakeToggle = CreateToggle("ScreenShakeToggle", panel.transform, "Screen Shake", new Vector2(150, 10));
            var subsToggle = CreateToggle("SubtitlesToggle", panel.transform, "Subtitles", new Vector2(-150, -40));
            var fullscreenToggle = CreateToggle("FullscreenToggle", panel.transform, "Fullscreen", new Vector2(150, -40));

            var backBtn = CreateButton("BackButton", panel.transform, "Back", new Vector2(0, -180));

            SetObjectField(settingsUI, "masterVolumeSlider", masterSlider);
            SetObjectField(settingsUI, "musicVolumeSlider", musicSlider);
            SetObjectField(settingsUI, "sfxVolumeSlider", sfxSlider);
            SetObjectField(settingsUI, "invertYToggle", invertToggle);
            SetObjectField(settingsUI, "screenShakeToggle", shakeToggle);
            SetObjectField(settingsUI, "subtitlesToggle", subsToggle);
            SetObjectField(settingsUI, "fullscreenToggle", fullscreenToggle);
            // qualityDropdown intentionally left unassigned: TMP_Dropdown's nested template
            // hierarchy is easiest/safest to build via GameObject > UI > Dropdown - TextMeshPro
            // in the Editor rather than hand-constructed here. See Docs/EditorSetupGuide.md.

            UnityEventTools.AddPersistentListener(masterSlider.onValueChanged, settingsUI.OnMasterVolumeChanged);
            UnityEventTools.AddPersistentListener(musicSlider.onValueChanged, settingsUI.OnMusicVolumeChanged);
            UnityEventTools.AddPersistentListener(sfxSlider.onValueChanged, settingsUI.OnSfxVolumeChanged);
            UnityEventTools.AddPersistentListener(invertToggle.onValueChanged, settingsUI.OnInvertYChanged);
            UnityEventTools.AddPersistentListener(shakeToggle.onValueChanged, settingsUI.OnScreenShakeChanged);
            UnityEventTools.AddPersistentListener(subsToggle.onValueChanged, settingsUI.OnSubtitlesChanged);
            UnityEventTools.AddPersistentListener(fullscreenToggle.onValueChanged, settingsUI.OnFullscreenChanged);
            UnityEventTools.AddPersistentListener(backBtn.onClick, settingsUI.OnBackClicked);

            masterSlider.value = 1f;
            musicSlider.value = 0.8f;
            sfxSlider.value = 1f;
            subsToggle.isOn = true;
            shakeToggle.isOn = true;
            fullscreenToggle.isOn = true;

            return panel;
        }

        private static void ConfigureBuildSettings()
        {
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(MainMenuScenePath, true),
                new EditorBuildSettingsScene(GameplayScenePath, true),
            };
        }

        // ------------------------------------------------------------------
        // UI construction helpers
        // ------------------------------------------------------------------

        private static GameObject CreateCanvas(string name)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = go.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = go.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920, 1080);
            return go;
        }

        private static void CreateEventSystem()
        {
            if (Object.FindObjectOfType<EventSystem>() != null) return;
            new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
        }

        private static GameObject CreatePanel(string name, Transform parent, Color background)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(Image));
            go.transform.SetParent(parent, false);
            StretchFull(go.GetComponent<RectTransform>());
            go.GetComponent<Image>().color = background;
            return go;
        }

        private static TextMeshProUGUI CreateLabel(string name, Transform parent, string text, float fontSize, Vector2 anchoredPos, Vector2 size)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(TextMeshProUGUI));
            go.transform.SetParent(parent, false);
            var rect = go.GetComponent<RectTransform>();
            CenterAnchor(rect);
            rect.sizeDelta = size;
            rect.anchoredPosition = anchoredPos;
            var tmp = go.GetComponent<TextMeshProUGUI>();
            tmp.text = text;
            tmp.fontSize = fontSize;
            tmp.alignment = TextAlignmentOptions.Center;
            tmp.color = Color.white;
            return tmp;
        }

        private static Button CreateButton(string name, Transform parent, string label, Vector2 anchoredPos)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(Image), typeof(Button));
            go.transform.SetParent(parent, false);
            var rect = go.GetComponent<RectTransform>();
            CenterAnchor(rect);
            rect.sizeDelta = new Vector2(280, 60);
            rect.anchoredPosition = anchoredPos;

            var image = go.GetComponent<Image>();
            image.color = new Color(0.2f, 0.45f, 0.85f, 1f);

            var button = go.GetComponent<Button>();
            button.targetGraphic = image;

            var textGO = new GameObject("Label", typeof(RectTransform), typeof(TextMeshProUGUI));
            textGO.transform.SetParent(go.transform, false);
            StretchFull(textGO.GetComponent<RectTransform>());
            var tmp = textGO.GetComponent<TextMeshProUGUI>();
            tmp.text = label;
            tmp.alignment = TextAlignmentOptions.Center;
            tmp.fontSize = 26;
            tmp.color = Color.white;

            return button;
        }

        private static Slider CreateSlider(string name, Transform parent, Vector2 anchoredPos)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(Slider));
            go.transform.SetParent(parent, false);
            var rect = go.GetComponent<RectTransform>();
            CenterAnchor(rect);
            rect.sizeDelta = new Vector2(280, 20);
            rect.anchoredPosition = anchoredPos;

            var bgGO = new GameObject("Background", typeof(RectTransform), typeof(Image));
            bgGO.transform.SetParent(go.transform, false);
            StretchFull(bgGO.GetComponent<RectTransform>());
            bgGO.GetComponent<Image>().color = new Color(1f, 1f, 1f, 0.15f);

            var fillAreaGO = new GameObject("Fill Area", typeof(RectTransform));
            fillAreaGO.transform.SetParent(go.transform, false);
            StretchFull(fillAreaGO.GetComponent<RectTransform>());

            var fillGO = new GameObject("Fill", typeof(RectTransform), typeof(Image));
            fillGO.transform.SetParent(fillAreaGO.transform, false);
            StretchFull(fillGO.GetComponent<RectTransform>());
            fillGO.GetComponent<Image>().color = new Color(0.3f, 0.6f, 1f, 1f);

            var handleAreaGO = new GameObject("Handle Slide Area", typeof(RectTransform));
            handleAreaGO.transform.SetParent(go.transform, false);
            StretchFull(handleAreaGO.GetComponent<RectTransform>());

            var handleGO = new GameObject("Handle", typeof(RectTransform), typeof(Image));
            handleGO.transform.SetParent(handleAreaGO.transform, false);
            handleGO.GetComponent<RectTransform>().sizeDelta = new Vector2(20, 20);
            handleGO.GetComponent<Image>().color = Color.white;

            var slider = go.GetComponent<Slider>();
            slider.targetGraphic = handleGO.GetComponent<Image>();
            slider.fillRect = fillGO.GetComponent<RectTransform>();
            slider.handleRect = handleGO.GetComponent<RectTransform>();
            slider.direction = Slider.Direction.LeftToRight;
            slider.minValue = 0f;
            slider.maxValue = 1f;

            return slider;
        }

        private static Toggle CreateToggle(string name, Transform parent, string label, Vector2 anchoredPos)
        {
            var go = new GameObject(name, typeof(RectTransform), typeof(Toggle));
            go.transform.SetParent(parent, false);
            var rect = go.GetComponent<RectTransform>();
            CenterAnchor(rect);
            rect.sizeDelta = new Vector2(220, 30);
            rect.anchoredPosition = anchoredPos;

            var bgGO = new GameObject("Background", typeof(RectTransform), typeof(Image));
            bgGO.transform.SetParent(go.transform, false);
            var bgRect = bgGO.GetComponent<RectTransform>();
            bgRect.anchorMin = new Vector2(0f, 0.5f);
            bgRect.anchorMax = new Vector2(0f, 0.5f);
            bgRect.pivot = new Vector2(0f, 0.5f);
            bgRect.sizeDelta = new Vector2(24, 24);
            bgRect.anchoredPosition = new Vector2(0, 0);
            bgGO.GetComponent<Image>().color = new Color(1f, 1f, 1f, 0.2f);

            var checkGO = new GameObject("Checkmark", typeof(RectTransform), typeof(Image));
            checkGO.transform.SetParent(bgGO.transform, false);
            StretchFull(checkGO.GetComponent<RectTransform>());
            checkGO.GetComponent<Image>().color = new Color(0.3f, 0.85f, 0.4f, 1f);

            var labelGO = new GameObject("Label", typeof(RectTransform), typeof(TextMeshProUGUI));
            labelGO.transform.SetParent(go.transform, false);
            var labelRect = labelGO.GetComponent<RectTransform>();
            labelRect.anchorMin = new Vector2(0f, 0f);
            labelRect.anchorMax = new Vector2(1f, 1f);
            labelRect.offsetMin = new Vector2(30, 0);
            labelRect.offsetMax = Vector2.zero;
            var tmp = labelGO.GetComponent<TextMeshProUGUI>();
            tmp.text = label;
            tmp.fontSize = 15;
            tmp.alignment = TextAlignmentOptions.MidlineLeft;
            tmp.color = Color.white;

            var toggle = go.GetComponent<Toggle>();
            toggle.targetGraphic = bgGO.GetComponent<Image>();
            toggle.graphic = checkGO.GetComponent<Image>();

            return toggle;
        }

        private static void CenterAnchor(RectTransform rt)
        {
            rt.anchorMin = new Vector2(0.5f, 0.5f);
            rt.anchorMax = new Vector2(0.5f, 0.5f);
            rt.pivot = new Vector2(0.5f, 0.5f);
        }

        private static void StretchFull(RectTransform rt)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        private static void AnchorTopLeft(RectTransform rt, Vector2 size, Vector2 pos)
        {
            rt.anchorMin = new Vector2(0f, 1f);
            rt.anchorMax = new Vector2(0f, 1f);
            rt.pivot = new Vector2(0f, 1f);
            rt.sizeDelta = size;
            rt.anchoredPosition = pos;
        }

        private static void AnchorTopCenter(RectTransform rt, Vector2 size, Vector2 pos)
        {
            rt.anchorMin = new Vector2(0.5f, 1f);
            rt.anchorMax = new Vector2(0.5f, 1f);
            rt.pivot = new Vector2(0.5f, 1f);
            rt.sizeDelta = size;
            rt.anchoredPosition = pos;
        }

        private static void AnchorTopRight(RectTransform rt, Vector2 size, Vector2 pos)
        {
            rt.anchorMin = new Vector2(1f, 1f);
            rt.anchorMax = new Vector2(1f, 1f);
            rt.pivot = new Vector2(1f, 1f);
            rt.sizeDelta = size;
            rt.anchoredPosition = pos;
        }

        // ------------------------------------------------------------------
        // Reflection-free private [SerializeField] access via SerializedObject
        // ------------------------------------------------------------------

        private static SerializedProperty FindPropertyOrLog(Object target, string fieldName)
        {
            var so = new SerializedObject(target);
            var prop = so.FindProperty(fieldName);
            if (prop == null)
            {
                Debug.LogError($"[SceneBuilder] Field '{fieldName}' not found on {target.GetType().Name}");
            }
            return prop;
        }

        private static void SetObjectField(Object target, string fieldName, Object value)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.objectReferenceValue = value;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetObjectArrayField(Object target, string fieldName, Object[] values)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.arraySize = values.Length;
            for (int i = 0; i < values.Length; i++)
            {
                prop.GetArrayElementAtIndex(i).objectReferenceValue = values[i];
            }
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetStringField(Object target, string fieldName, string value)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.stringValue = value;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetFloatField(Object target, string fieldName, float value)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.floatValue = value;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetIntField(Object target, string fieldName, int value)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.intValue = value;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetBoolField(Object target, string fieldName, bool value)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.boolValue = value;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void SetEnumIndexField(Object target, string fieldName, int enumIndex)
        {
            var prop = FindPropertyOrLog(target, fieldName);
            if (prop == null) return;
            prop.enumValueIndex = enumIndex;
            prop.serializedObject.ApplyModifiedProperties();
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;

            var parts = path.Split('/');
            string current = parts[0];
            for (int i = 1; i < parts.Length; i++)
            {
                string next = current + "/" + parts[i];
                if (!AssetDatabase.IsValidFolder(next))
                {
                    AssetDatabase.CreateFolder(current, parts[i]);
                }
                current = next;
            }
        }
    }
}
