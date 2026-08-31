#pragma once

#include "Types.h"
#include "MIPS.h"
#include "sound/SoundHandler.h"
#include "PsfVmSubSystem.h"
#include "VirtualMachine.h"
#include "Debuggable.h"
#include "MailBox.h"
#include <thread>
#include <functional>
#include <mutex>
#include <string>
#include "filesystem_def.h"

class CPsfVm : public CVirtualMachine
{
public:
	typedef std::function<CSoundHandler*()> SpuHandlerFactory;
	typedef std::function<void(const std::string&)> ErrorHandler;
	typedef Framework::CSignal<void()> NewFrameEvent;

	CPsfVm();
	virtual ~CPsfVm();

	void Reset();
	void Step();
	void SetSpuHandler(const SpuHandlerFactory&);
	void SetErrorHandler(const ErrorHandler&);
	bool HasError() const;
	std::string GetErrorMessage() const;
	void ClearError();

	void SetReverbEnabled(bool);
	void SetVolumeAdjust(float);

	CMIPS& GetCpu();
	uint8* GetRam();
	uint32 GetRamSize();
	Iop::CSpuBase& GetSpuCore(unsigned int);

	void SetSubSystem(const PsfVmSubSystemPtr&);

	CDebuggable GetDebugInfo();

	STATUS GetStatus() const override;
	void Pause() override;
	void Resume() override;

#ifdef DEBUGGER_INCLUDED
	fs::path MakeDebugTagsPackagePath(const char*);
	void LoadDebugTags(const char*);
	void SaveDebugTags(const char*);
#endif

	NewFrameEvent OnNewFrame;

protected:
	CMailBox m_mailBox;

private:
	void ThreadProc();

	void SetReverbEnabledImpl(bool);
	void SetVolumeAdjustImpl(float);
	void PauseImpl();
	void SetSpuHandlerImpl(const SpuHandlerFactory&);
	void ReportThreadError(const std::string&);

	STATUS m_status;
	PsfVmSubSystemPtr m_subSystem;
	CSoundHandler* m_soundHandler;
	std::thread m_thread;
	bool m_singleStep;
	bool m_isThreadOver;
	Framework::CSignal<void()>::Connection m_OnNewFrameConnection;
	mutable std::mutex m_errorMutex;
	std::string m_errorMessage;
	ErrorHandler m_errorHandler;
};
