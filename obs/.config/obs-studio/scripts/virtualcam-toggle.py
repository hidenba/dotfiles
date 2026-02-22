import obspython as obs

CAMERA_DEVICE = "/dev/video0"


def log(msg):
    obs.script_log(obs.LOG_INFO, msg)


def on_event(event):
    if event == obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STARTED:
        log("Event: VIRTUALCAM_STARTED")
        restore_cameras()
    elif event == obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STOPPED:
        log("Event: VIRTUALCAM_STOPPED")
        disable_cameras()
    elif event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING:
        obs.timer_add(initial_disable, 2000)


def initial_disable():
    obs.timer_remove(initial_disable)
    log("Running initial_disable")
    disable_cameras()


def disable_cameras():
    sources = obs.obs_enum_sources()
    for source in sources:
        source_id = obs.obs_source_get_unversioned_id(source)
        if source_id == "v4l2_input":
            name = obs.obs_source_get_name(source)
            # Disable source first to release camera
            obs.obs_source_set_enabled(source, False)
            # Then clear device_id
            settings = obs.obs_source_get_settings(source)
            obs.obs_data_set_string(settings, "device_id", "")
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            log(f"Disabled camera: {name}")
    obs.source_list_release(sources)


def restore_cameras():
    sources = obs.obs_enum_sources()
    for source in sources:
        source_id = obs.obs_source_get_unversioned_id(source)
        if source_id == "v4l2_input":
            name = obs.obs_source_get_name(source)
            # Restore device_id
            settings = obs.obs_source_get_settings(source)
            obs.obs_data_set_string(settings, "device_id", CAMERA_DEVICE)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            log(f"Restored camera: {name} -> {CAMERA_DEVICE}")
    obs.source_list_release(sources)
    # Re-enable after a short delay
    obs.timer_add(enable_sources, 500)


def enable_sources():
    obs.timer_remove(enable_sources)
    log("Enabling sources")
    sources = obs.obs_enum_sources()
    for source in sources:
        source_id = obs.obs_source_get_unversioned_id(source)
        if source_id == "v4l2_input":
            obs.obs_source_set_enabled(source, True)
    obs.source_list_release(sources)


def script_load(settings):
    obs.obs_frontend_add_event_callback(on_event)


def script_description():
    return "Release camera when virtual camera stops, reacquire when started."
