// SPDX-License-Identifier: BSD-3-Clause
// Tests the real DRM output/connector teardown; only the kernel commit is fake.
#include <aquamarine/backend/Backend.hpp>
#include <aquamarine/backend/DRM.hpp>
#include <aquamarine/backend/Session.hpp>
#include <hyprutils/memory/SharedPtr.hpp>
#include <iostream>

using namespace Aquamarine;
using namespace Hyprutils::Memory;

class FakeKMS : public IDRMImplementation {
  public:
    int calls = 0;
    bool accept = true;
    bool disabled = false;
    bool blockingModeset = false;

    bool commit(CSharedPointer<SDRMConnector>, SDRMConnectorCommitData& data) override {
        ++calls;
        disabled = !data.enabled;
        blockingModeset = data.blocking && data.modeset && !(data.flags & DRM_MODE_PAGE_FLIP_EVENT);
        return accept;
    }
    bool reset() override { return true; }
    bool moveCursor(CSharedPointer<SDRMConnector>, bool) override { return true; }
};

struct Fixture {
    CSharedPointer<CBackend> core;
    CSharedPointer<CDRMBackend> drm;
    CSharedPointer<FakeKMS> kms = makeShared<FakeKMS>();
    CSharedPointer<SDRMConnector> connector = makeShared<SDRMConnector>();
    CSharedPointer<CDRMOutput> output;

    Fixture() {
        SBackendImplementationOptions options;
        options.backendType = AQ_BACKEND_NULL;
        core = CBackend::create({options}, SBackendOptions{});
        core->session = makeShared<CSession>();
        drm = CSharedPointer<CDRMBackend>(new CDRMBackend(core));
        drm->self = drm;
        drm->impl = kms;
        connector->backend = drm;
        connector->self = connector;
        connector->status = DRM_MODE_CONNECTED;
        connector->crtc = makeShared<SDRMCRTC>();
        connector->crtc->id = 269;
        connector->crtc->primary = makeShared<SDRMPlane>();
        output = CSharedPointer<CDRMOutput>(new CDRMOutput("HDMI-A-1", drm, connector));
        output->self = output;
        connector->output = output;
        auto mode = makeShared<SOutputMode>();
        mode->pixelSize = {1920, 1080};
        mode->refreshRate = 60000;
        mode->modeInfo = drmModeModeInfo{};
        output->modes.push_back(mode);
        output->state->setMode(mode);
        output->state->setEnabled(true);
        output->state->setFormat(DRM_FORMAT_XRGB8888);
        output->state->consume(output->state->snapshot());
    }
    ~Fixture() { connector->output.reset(); }
};

int main() {
    int failures = 0;
    auto check = [&](bool result, const char* description) {
        std::cout << (result ? "PASS " : "FAIL ") << description << '\n';
        failures += !result;
    };
    {
        Fixture f;
        bool notified = false;
        auto listener = f.output->events.destroy.listen([&] {
            notified = true;
            check(f.connector->status == DRM_MODE_DISCONNECTED, "destroy follows disconnect status");
            f.output->state->setEnabled(true);
            check(!f.output->commit() && f.kms->calls == 0, "enable rejected during destruction");
            f.output->state->setEnabled(false);
            check(f.output->commit(), "destroy callback can disable output");
            check(f.kms->calls == 1 && f.kms->disabled && f.kms->blockingModeset,
                  "exactly one synchronous disable reaches KMS");
            check(!f.output->enabledState, "accepted disable updates actual output state");
        });
        f.connector->disconnect();
        check(notified && !f.connector->output, "output detached after cleanup");
        f.output->state->setEnabled(false);
        check(!f.output->commit() && f.kms->calls == 1, "stale output cannot commit after detach");
    }
    {
        Fixture f;
        f.connector->status = DRM_MODE_DISCONNECTED;
        f.output->state->setEnabled(false);
        f.output->state->consume(f.output->state->snapshot());
        f.output->state->addDamage({0, 0, 10, 10});
        check(!f.output->commit() && f.kms->calls == 0, "unrelated commit rejected on disconnected output");
        SDRMConnectorCommitData data;
        data.enabled = true;
        data.committed = COutputState::AQ_OUTPUT_STATE_ENABLED;
        check(!f.connector->commitState(data) && f.kms->calls == 0, "connector also rejects disconnected enable");
        data.enabled = false;
        data.committed = 0;
        check(!f.connector->commitState(data) && f.kms->calls == 0, "connector requires an explicit disable");
    }
    {
        Fixture f;
        f.connector->status = DRM_MODE_DISCONNECTED;
        f.output->state->setEnabled(false);
        f.kms->accept = false;
        check(!f.output->commit() && f.kms->calls == 1, "kernel rejection is propagated");
        check(f.output->enabledState, "rejected disable does not pretend the output is off");
        f.kms->accept = true;
        check(f.output->commit() && f.kms->calls == 2, "failed disable remains retryable");
    }
    {
        Fixture f;
        f.core->session->active = false;
        f.output->state->setEnabled(false);
        check(!f.output->commit() && f.kms->calls == 0, "inactive session cannot alter the display");
        f.core->session->active = true;
        check(f.output->commit() && f.kms->calls == 1, "ordinary connected disable still works");
    }
    return failures ? 1 : 0;
}
