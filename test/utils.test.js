const { showToast, toggleSidebar } = require('../utils.js');

describe('Utils Functions', () => {
    beforeEach(() => {
        // Set up the DOM before each test
        document.body.innerHTML = `
            <div id="toast-container"></div>
            <div id="sidebar" class=""></div>
        `;
        
        jest.useFakeTimers();
    });

    afterEach(() => {
        jest.useRealTimers();
    });

    describe('showToast', () => {
        it('should create a toast element with the correct message and type', () => {
            showToast('Test message', 'success');
            
            const container = document.getElementById('toast-container');
            expect(container.children.length).toBe(1);
            
            const toast = container.children[0];
            expect(toast.className).toBe('toast success');
            expect(toast.innerHTML).toContain('Test message');
            expect(toast.innerHTML).toContain('✅');
        });

        it('should add "show" class after a short delay', () => {
            showToast('Test show class');
            const toast = document.querySelector('.toast');
            
            expect(toast.classList.contains('show')).toBe(false);
            
            // Advance timers to trigger the first setTimeout (10ms)
            jest.advanceTimersByTime(15);
            
            expect(toast.classList.contains('show')).toBe(true);
        });
    });

    describe('toggleSidebar', () => {
        it('should toggle the "open" class on the sidebar', () => {
            const sidebar = document.getElementById('sidebar');
            
            expect(sidebar.classList.contains('open')).toBe(false);
            
            toggleSidebar();
            expect(sidebar.classList.contains('open')).toBe(true);
            
            toggleSidebar();
            expect(sidebar.classList.contains('open')).toBe(false);
        });
    });
});
