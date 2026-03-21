/**
 * @file runtime.c
 * @brief XY Language Runtime Library (v0.1) - Cross-Platform Version
 * @description �Ƴ�����??POSIX ���� (unistd.h)����ʹ�ñ�׼ C99
 *              ���� Windows (MSVC/MinGW), Linux, macOS ���޷��??
 */

/* ���� MSVC ��ȫ���� */
#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* Windows �ض�ͷ��??*/
#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>

/* Windows ����??UTF-8 ��ʼ??*/
static int g_console_initialized = 0;

/**
 * ��ʼ??Windows ����̨��֧�� UTF-8 ���
 * �����ڳ������ʱ����һ??
 */
static void init_windows_console(void) {
    if (g_console_initialized) return;
    g_console_initialized = 1;
    
    /* ���ÿ���̨�������ҳ??UTF-8 */
    SetConsoleOutputCP(65001);
    SetConsoleCP(65001);
}

/* �Զ���ʼ����??*/
__attribute__((constructor))
static void auto_init_console(void) {
    init_windows_console();
}
#endif

/* === �ڲ��ṹ���� (���û�͸��) === */

/**
 * �ַ����ṹ������ + ���� (UTF-8 �ֽ�??
 */
typedef struct {
    int64_t len;
    char* data;
} XyString;

/**
 * �б�ṹ����̬���飬�洢 void* (���Ͳ���)
 */
typedef struct {
    int64_t count;
    int64_t capacity;
    void** items;
} XyList;

/* === �ַ�??API === */

/**
 * �����ַ�??(??C const char*)
 * @param utf8_content UTF-8 ������ַ�������
 * @return �ַ���ָ�룬ʧ�ܷ��� NULL
 */
void* rt_string_new(const char* utf8_content) {
    if (!utf8_content) return NULL;
    
    XyString* s = (XyString*)malloc(sizeof(XyString));
    if (!s) return NULL;
    
    s->len = (int64_t)strlen(utf8_content);  /* �ֽڳ��ȣ����ַ�??*/
    s->data = (char*)malloc(s->len + 1);
    if (!s->data) {
        free(s);
        return NULL;
    }
    
    memcpy(s->data, utf8_content, s->len + 1);  /* ���� '\0' */
    return (void*)s;
}

/**
 * ��ȡ�ַ�����??(�ֽ�??
 * @param s_ptr �ַ���ָ??
 * @return �ֽڳ���
 */
int64_t rt_string_len(void* s_ptr) {
    if (!s_ptr) return 0;
    return ((XyString*)s_ptr)->len;
}

/**
 * �ͷ��ַ�??
 * @param s_ptr �ַ���ָ??
 */
void rt_string_free(void* s_ptr) {
    if (!s_ptr) return;
    XyString* s = (XyString*)s_ptr;
    if (s->data) free(s->data);
    free(s);
}

/* === �б� API (���Ͳ������洢ָ?? === */

/**
 * ��������??
 * @return �б�ָ�룬ʧ�ܷ�??NULL
 */
void* rt_list_new() {
    XyList* list = (XyList*)malloc(sizeof(XyList));
    if (!list) return NULL;
    
    list->count = 0;
    list->capacity = 8;  /* ��ʼ���� */
    list->items = (void**)malloc(list->capacity * sizeof(void*));
    if (!list->items) {
        free(list);
        return NULL;
    }
    return (void*)list;
}

/**
 * ���б�׷��Ԫ??
 * @param list_ptr �б�ָ��
 * @param item Ҫ��ӵ�Ԫ��ָ��
 */
void rt_list_append(void* list_ptr, void* item) {
    if (!list_ptr) return;
    XyList* list = (XyList*)list_ptr;
    
    if (list->count >= list->capacity) {
        /* ���� 2 ??*/
        int64_t new_cap = list->capacity * 2;
        void** new_items = (void**)realloc(list->items, new_cap * sizeof(void*));
        if (!new_items) return;  /* �򵥴��������ʧ�ܺ��� */
        list->items = new_items;
        list->capacity = new_cap;
    }
    
    list->items[list->count++] = item;
}

/**
 * ��ȡ�б�Ԫ��
 * @param list_ptr �б�ָ��
 * @param index ���� (??0 ��??
 * @return Ԫ��ָ�룬Խ�緵??NULL
 */
void* rt_list_get(void* list_ptr, int64_t index) {
    if (!list_ptr) return NULL;
    XyList* list = (XyList*)list_ptr;
    
    if (index >= list->count) {  /* �޸���Ӧ���� >= ����??= */
        /* Խ�紦�����??NULL */
        return NULL;
    }
    return list->items[index];
}

/**
 * ��ȡ�б����
 * @param list_ptr �б�ָ��
 * @return Ԫ������
 */
int64_t rt_list_len(void* list_ptr) {
    if (!list_ptr) return 0;
    return ((XyList*)list_ptr)->count;
}

/**
 * �ͷ��б�
 * @param list_ptr �б�ָ��
 */
void rt_list_free(void* list_ptr) {
    if (!list_ptr) return;
    XyList* list = (XyList*)list_ptr;
    if (list->items) free(list->items);
    free(list);
}

/* === IO API === */

/**
 * ��ӡ�ַ���������
 * @param s_ptr �ַ���ָ??
 */
void rt_println(void* s_ptr) {
    if (!s_ptr) {
        printf("\n");
        return;
    }
    XyString* s = (XyString*)s_ptr;
    /* ֱ����� UTF-8 �ֽ������ն˻��Զ���??*/
    fwrite(s->data, 1, s->len, stdout);
    printf("\n");
    fflush(stdout);
}

/**
 * ��ȡһ??(�������з���??
 * @return �ַ���ָ�룬EOF ����󷵻ؿ�??
 */
void* rt_readline() {
    char buffer[4096];  /* ���Ƶ������??*/
    if (fgets(buffer, sizeof(buffer), stdin) == NULL) {
        return rt_string_new("");  /* EOF ����󷵻ؿ�??*/
    }
    
    /* ȥ��ĩβ����??(\n ??\r\n) */
    size_t len = strlen(buffer);
    while (len > 0 && (buffer[len-1] == '\n' || buffer[len-1] == '\r')) {
        buffer[--len] = '\0';
    }
    
    return rt_string_new(buffer);
}

/* === ���ݾɰ汾�ı������� === */

/**
 * ��ӡ���� (���ݾɰ�??
 * @param str Ҫ��ӡ���ַ�??
 * @return 0 ��ʾ�ɹ�
 */

/**
 * ��ӡ�ַ�??(void* �汾����??LLVM IR ����)
 * ֧�����ָ�ʽ??
 * 1. XyString* �ṹָ��
 * 2. ԭʼ C �ַ�??(i8* ָ����)
 * @param str_ptr �ַ���ָ??
 */
void print(void* str_ptr) {
    if (!str_ptr) {
        printf("(null)");
        return;
    }
    
    /* ��ȡָ���ַ */
    uintptr_t addr = (uintptr_t)str_ptr;
    
    /* 
     * ����Ƿ��Ƕѷ���� XyString �ṹ
     * �ѵ�ַͨ����ĳ����Χ�ڣ�ȡ����ϵͳ??
     * Windows: 0x00010000 - 0x7FFFFFFF (�û��ռ�)
     * ���ⲻ�ɿ����������ǻ�һ�ַ�??
     */
    
    /* ��ȡ��һ���ֽ���Ϊ��??*/
    unsigned char first_byte = *(unsigned char*)str_ptr;
    
    /* 
     * �ַ�������ͨ���Կɴ�ӡ�ַ���??
     * XyString �ṹ�ĵ�һ����??len �ֶΣ�Ӧ��������??
     */
    if (first_byte >= 32 && first_byte <= 126) {
        /* ����������ͨ�ַ���ͷ��??C �ַ�����??*/
        printf("%s", (const char*)str_ptr);
        return;
    }
    
    /* ����Ƿ��� XyString �ṹ */
    XyString* s = (XyString*)str_ptr;
    if (s->len > 0 && s->len < 1024*1024 && s->data != NULL) {
        /* ����������Ч??XyString */
        fwrite(s->data, 1, s->len, stdout);
        return;
    }
    
    /* Ĭ��??C �ַ�����??*/
    printf("%s", (const char*)str_ptr);
}

/**
 * ��ӡ���� (void �汾����??LLVM IR)
 * @param val Ҫ��ӡ������
 */
void print_int(int64_t val) {
    printf("%lld", (long long)val);
}

/**
 * ��ӡ����??(void �汾����??LLVM IR)
 * @param val Ҫ��ӡ�ĸ���??
 */
void print_float(double val) {
    printf("%f", val);
}

/**
 * ��ӡ����??(void �汾����??LLVM IR)
 * @param val Ҫ��ӡ�Ĳ���??(0=false, 1=true)
 */
void print_bool(int val) {
    printf("%s", val ? "true" : "false");
}

/**
 * ��ӡ�ַ�??(const char* �汾�����ݾɴ���)
 * @param str Ҫ��ӡ���ַ�??
 * @return 0 ��ʾ�ɹ�
 */
int ��ӡ(const char* str) {
    printf("%s", str);
    return 0;
}

/**
 * ��ӡ�������� (���ݾɰ�??
 * @param val Ҫ��ӡ������
 * @return 0 ��ʾ�ɹ�
 */
int ��ӡ����(int64_t val) {
    printf("%lld", (long long)val);
    return 0;
}

/**
 * ��ӡ����
 * @return 0 ��ʾ�ɹ�
 */
int ��ӡ����() {
    printf("\n");
    return 0;
}

/**
 * �������� - �ӿ���̨��ȡһ����??
 * @return ��ȡ����������ʧ�ܷ�??0
 */
int64_t ��������() {
    int64_t val;
    if (scanf("%lld", &val) == 1) {
        return val;
    }
    return 0;
}

/**
 * �����ı� - �ӿ���̨��ȡһ����??
 * @return ��ȡ�����ı��У�EOF ����󷵻ؿ�??
 */
void* �����ı�() {
    return rt_readline();
}

/**
 * ��ʱ���� (����)
 * @param ms ��ʱ����??
 */
void ��ʱ(int ms) {
#ifdef _WIN32
    Sleep(ms);
#else
    usleep(ms * 1000);
#endif
}

/**
 * �˳���??
 * @param code �˳���
 */
void ��??int code) {
    exit(code);
}

/**
 * ��ȡ���??
 * @return �������
 */
int ���??) {
    return rand();
}

/* === �������� === */

/**
 * ����??panic
 * @param msg ������Ϣ
 */
void rt_panic(const char* msg) {
    fprintf(stderr, "XY Runtime Panic: %s\n", msg);
    exit(1);
}

/* === �ļ� I/O API === */

/**
 * ��ȡ�ļ�����
 * @param path �ļ�·�� (UTF-8 �ַ�??
 * @return �ļ������ַ���ָ�룬ʧ�ܷ��� NULL
 */
void* �ļ���ȡ(const char* path) {
    if (!path) return NULL;
    
    FILE* f = fopen(path, "rb");  /* ������ģʽ��??*/
    if (!f) return NULL;
    
    /* ��ȡ�ļ���С */
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    if (size < 0) {
        fclose(f);
        return NULL;
    }
    
    /* �����ڴ� */
    XyString* s = (XyString*)malloc(sizeof(XyString));
    if (!s) {
        fclose(f);
        return NULL;
    }
    
    s->len = size;
    s->data = (char*)malloc(size + 1);
    if (!s->data) {
        free(s);
        fclose(f);
        return NULL;
    }
    
    /* ��ȡ���� */
    size_t read_size = fread(s->data, 1, size, f);
    s->data[read_size] = '\0';
    fclose(f);
    
    return (void*)s;
}

/**
 * д���ļ�����
 * @param path �ļ�·�� (UTF-8 �ַ�??
 * @param content �ļ�����
 * @return 0 ��ʾ�ɹ�??1 ��ʾʧ��
 */
int �ļ�д��(const char* path, const char* content) {
    if (!path || !content) return -1;
    
    FILE* f = fopen(path, "wb");  /* ������ģʽд??*/
    if (!f) return -1;
    
    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, f);
    fclose(f);
    
    return (written == len) ? 0 : -1;
}

/**
 * ����ļ��Ƿ��??
 * @param path �ļ�·��
 * @return 1 ��ʾ����?? ��ʾ����??
 */
int �ļ�����(const char* path) {
    if (!path) return 0;
    FILE* f = fopen(path, "r");
    if (f) {
        fclose(f);
        return 1;
    }
    return 0;
}

/**
 * ɾ���ļ�
 * @param path �ļ�·��
 * @return 0 ��ʾ�ɹ�??1 ��ʾʧ��
 */
int �ļ�ɾ��(const char* path) {
    if (!path) return -1;
    return remove(path);
}

/* === ϵͳ����ִ�� API === */

#ifdef _WIN32
#include <process.h>
#define popen _popen
#define pclose _pclose
#endif

/**
 * ִ��ϵͳ����
 * @param cmd �����ַ�??
 * @return �����˳���
 */
int ִ������(const char* cmd) {
    if (!cmd) return -1;
    
    int result = system(cmd);
    return result;
}

/* Ӣ�ı��� - Windows ��֧�� alias ���ԣ�ֱ�Ӷ��� */
int exec_cmd(const char* cmd) {
    return ִ������;
}

/**
 * ִ�������ȡ��??
 * @param cmd �����ַ�??
 * @return ��������ַ���ָ�룬ʧ�ܷ��� NULL
 */
void* �������(const char* cmd) {
    if (!cmd) return NULL;
    
    FILE* pipe = popen(cmd, "r");
    if (!pipe) return NULL;
    
    /* ��̬������ */
    size_t capacity = 4096;
    size_t len = 0;
    char* buffer = (char*)malloc(capacity);
    if (!buffer) {
        pclose(pipe);
        return NULL;
    }
    
    /* ��ȡ��� */
    char line[1024];
    while (fgets(line, sizeof(line), pipe)) {
        size_t line_len = strlen(line);
        if (len + line_len + 1 > capacity) {
            capacity *= 2;
            char* new_buf = (char*)realloc(buffer, capacity);
            if (!new_buf) {
                free(buffer);
                pclose(pipe);
                return NULL;
            }
            buffer = new_buf;
        }
        strcpy(buffer + len, line);
        len += line_len;
    }
    pclose(pipe);
    
    /* ���������ַ�??*/
    XyString* s = (XyString*)malloc(sizeof(XyString));
    if (!s) {
        free(buffer);
        return NULL;
    }
    
    s->len = len;
    s->data = buffer;
    return (void*)s;
}

/* Ӣ�ı��� - Windows ��֧�� alias ���ԣ�ֱ�Ӷ��� */
void* cmd_output(const char* cmd) {
    return �������;
}

/* === �����в�??API === */

static int g_argc = 0;
static char** g_argv = NULL;

/**
 * ��ʼ�������в��� (�ɱ���������??main ����)
 */
void rt_init_args(int argc, char** argv) {
    g_argc = argc;
    g_argv = argv;
}

/**
 * ��ȡ��������
 * @return ��������
 */
int ��������() {
    return g_argc;
}

/**
 * ��ȡ����
 * @param index �������� (0 = ����??
 * @return �����ַ���ָ??
 */
void* ��ȡ����(int index) {
    if (index < 0 || index >= g_argc) return NULL;
    return rt_string_new(g_argv[index]);
}

/* === �ַ�����??API === */

/**
 * �ַ�����??
 * @param str_ptr Դ�ַ���ָ��
 * @param start ��ʼλ��
 * @param length ��Ƭ����
 * @return ���ַ���ָ��
 */
void* �ı���Ƭ(void* str_ptr, int64_t start, int64_t length) {
    if (!str_ptr) return rt_string_new("");
    
    /* ������Ϊ XyString ���� */
    XyString* s = (XyString*)str_ptr;
    
    /* ����Ƿ�����Ч??XyString */
    if (s->len > 0 && s->len < 1024*1024 && s->data != NULL) {
        /* �߽��??*/
        if (start < 0) start = 0;
        if (start >= s->len) return rt_string_new("");
        if (length <= 0 || start + length > s->len) {
            length = s->len - start;
        }
        
        /* �������ַ��� */
        XyString* result = (XyString*)malloc(sizeof(XyString));
        if (!result) return NULL;
        
        result->len = length;
        result->data = (char*)malloc(length + 1);
        if (!result->data) {
            free(result);
            return NULL;
        }
        
        memcpy(result->data, s->data + start, length);
        result->data[length] = '\0';
        return (void*)result;
    }
    
    /* ��Ϊ��??C �ַ�����??*/
    const char* cstr = (const char*)str_ptr;
    size_t len = strlen(cstr);
    
    if (start < 0) start = 0;
    if (start >= (int64_t)len) return rt_string_new("");
    if (length <= 0 || start + length > (int64_t)len) {
        length = len - start;
    }
    
    XyString* result = (XyString*)malloc(sizeof(XyString));
    if (!result) return NULL;
    
    result->len = length;
    result->data = (char*)malloc(length + 1);
    if (!result->data) {
        free(result);
        return NULL;
    }
    
    memcpy(result->data, cstr + start, length);
    result->data[length] = '\0';
    return (void*)result;
}

/**
 * ��ȡ�ַ�����??
 * @param str_ptr �ַ���ָ??
 * @return �ַ�����??
 */
int64_t �ı�����(void* str_ptr) {
    if (!str_ptr) return 0;
    
    XyString* s = (XyString*)str_ptr;
    if (s->len > 0 && s->len < 1024*1024 && s->data != NULL) {
        return s->len;
    }
    
    return strlen((const char*)str_ptr);
}

/**
 * ����ת��??
 * @param val ����??
 * @return �ַ���ָ??
 */
void* ����ת��??int64_t val) {
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%lld", (long long)val);
    return rt_string_new(buffer);
}

/**
 * �ı�ת��??
 * @param str_ptr �ַ���ָ??
 * @return ����??
 */
int64_t �ı�ת��??void* str_ptr) {
    if (!str_ptr) return 0;
    
    XyString* s = (XyString*)str_ptr;
    if (s->len > 0 && s->len < 1024*1024 && s->data != NULL) {
        long long val = 0;
        sscanf(s->data, "%lld", &val);
        return (int64_t)val;
    }
    
    long long val = 0;
    sscanf((const char*)str_ptr, "%lld", &val);
    return (int64_t)val;
}

