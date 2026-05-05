import {
  startContinuousScanner,
  stopContinuousScanner,
  isContinuousScannerRunning,
  rescanSafely,
} from "../src/continuous_scanner"
import * as scanner from "../src/managed_service_scanner"
import { discoveries, clearDiscoveries } from "../src/discovery"

describe("ContinuousScanner", () => {
  beforeEach(() => {
    stopContinuousScanner()
    clearDiscoveries()
  })
  afterEach(() => stopContinuousScanner())

  describe("rescanSafely", () => {
    it("appends discoveries from scanManagedServices to the registry", () => {
      jest.spyOn(scanner, "scanManagedServices").mockReturnValue([
        { type: "database", tech: "postgresql", source: "env_detection", variable_name: "DATABASE_URL" }
      ])
      rescanSafely()
      expect(discoveries().length).toBeGreaterThanOrEqual(1)
    })

    it("does no-op when scanner returns empty", () => {
      jest.spyOn(scanner, "scanManagedServices").mockReturnValue([])
      rescanSafely()
      expect(discoveries().length).toBe(0)
    })

    it("swallows scanner errors without throwing", () => {
      jest.spyOn(scanner, "scanManagedServices").mockImplementation(() => {
        throw new Error("boom")
      })
      expect(() => rescanSafely()).not.toThrow()
    })
  })

  describe("start / stop lifecycle", () => {
    it("schedules a setInterval timer on start", () => {
      const setIntervalSpy = jest.spyOn(global, "setInterval")
      startContinuousScanner({ intervalMs: 1000 })
      expect(setIntervalSpy).toHaveBeenCalled()
      expect(isContinuousScannerRunning()).toBe(true)
    })

    it("is idempotent — second start does not schedule a second timer", () => {
      const setIntervalSpy = jest.spyOn(global, "setInterval")
      startContinuousScanner({ intervalMs: 1000 })
      const callsAfterFirst = setIntervalSpy.mock.calls.length
      startContinuousScanner({ intervalMs: 1000 })
      expect(setIntervalSpy.mock.calls.length).toBe(callsAfterFirst)
    })

    it("calls timer.unref() so the process can exit cleanly", () => {
      const unrefSpy = jest.fn()
      const fakeTimer = { unref: unrefSpy } as unknown as NodeJS.Timeout
      jest.spyOn(global, "setInterval").mockReturnValueOnce(fakeTimer)
      startContinuousScanner({ intervalMs: 1000 })
      expect(unrefSpy).toHaveBeenCalled()
    })

    it("stop clears the timer", () => {
      startContinuousScanner({ intervalMs: 1000 })
      expect(isContinuousScannerRunning()).toBe(true)
      stopContinuousScanner()
      expect(isContinuousScannerRunning()).toBe(false)
    })

    it("does nothing when disable: true is passed", () => {
      const setIntervalSpy = jest.spyOn(global, "setInterval")
      const callsBefore    = setIntervalSpy.mock.calls.length
      startContinuousScanner({ disable: true })
      expect(setIntervalSpy.mock.calls.length).toBe(callsBefore)
      expect(isContinuousScannerRunning()).toBe(false)
    })
  })
})
